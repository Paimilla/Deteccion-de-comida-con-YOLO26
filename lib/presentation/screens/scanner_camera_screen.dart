import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' as barcode;
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../application/app_services.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/app_notifier.dart';
import '../widgets/nutrifoto_ui.dart';
import '../widgets/skeleton_loader.dart';

/// Unified food-adding screen with persistent bottom tab bar.
/// Tab 0: Escanear (camera with food/barcode toggle)
/// Tab 1: Recetas
/// Tab 2: Buscar
/// Tab 3: Lista (manual)
/// Tab 4: Voz
class ScannerCameraScreen extends StatefulWidget {
  final AppServices services;

  const ScannerCameraScreen({super.key, required this.services});

  @override
  State<ScannerCameraScreen> createState() => _ScannerCameraScreenState();
}

class _ScannerCameraScreenState extends State<ScannerCameraScreen>
    with TickerProviderStateMixin {
  // --- Shared state ---
  MealSlot _mealSlot = MealSlot.desayuno;
  int _selectedTab = 0;
  bool _argsApplied = false;

  // --- Camera tab state ---
  CameraController? _cameraController;
  barcode.MobileScannerController? _barcodeController;
  bool _cameraReady = false;
  bool _flashEnabled = false;
  bool _capturing = false;
  bool _captureFlash = false;
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _capturedImagePath;
  FoodItem? _result;
  bool _barcodeMode = false; // false=comida, true=código de barras
  int _scanStep = 0;
  double _scanProgress = 0;

  // Scanner stage for camera tab only
  int _cameraStage = 0; // 0=camera, 1=analyzing, 2=result

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // --- Search tab state ---
  final _searchCtrl = TextEditingController();
  bool _searchLoading = false;
  List<FoodItem> _searchResults = const [];

  // --- Recipes tab state ---
  final _recipeCtrl = TextEditingController();
  bool _recipeLoading = false;
  List<FoodItem> _recipeResults = const [];

  // --- Voice tab state ---
  final _voiceCtrl = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  bool _voiceLoading = false;
  String? _voiceResult;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _initSpeech();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['mealSlot'] is MealSlot) {
      _mealSlot = args['mealSlot'] as MealSlot;
    }
    _argsApplied = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCamera();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.dispose();
    _barcodeController?.dispose();
    _searchCtrl.dispose();
    _recipeCtrl.dispose();
    _voiceCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  /// Disposes the food camera and starts the barcode scanner.
  Future<void> _switchToBarcodeMode() async {
    // First dispose the existing camera controller to release the hardware
    await _cameraController?.dispose();
    _cameraController = null;
    _cameraReady = false;
    _flashEnabled = false;

    // Create a fresh barcode controller
    _barcodeController = barcode.MobileScannerController();
    setState(() => _barcodeMode = true);
  }

  /// Disposes the barcode scanner and restarts the food camera.
  Future<void> _switchToFoodMode() async {
    // Dispose the barcode controller to release the hardware
    await _barcodeController?.dispose();
    _barcodeController = null;

    setState(() => _barcodeMode = false);

    // Reinitialize food camera
    await _initializeCamera();
  }

  // ===== CAMERA METHODS =====
  Future<void> _initializeCamera() async {
    setState(() {
      _cameraReady = false;
      _error = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'No se encontró cámara disponible');
        return;
      }

      final selected = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(selected, ResolutionPreset.high);
      await _cameraController!.initialize();

      if (!mounted) return;
      setState(() => _cameraReady = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Error inicializando cámara: $e');
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      HapticFeedback.lightImpact();
      await controller.setFlashMode(
        _flashEnabled ? FlashMode.off : FlashMode.torch,
      );
      setState(() => _flashEnabled = !_flashEnabled);
    } catch (_) {}
  }

  Future<void> _captureAndAnalyze() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        _loading ||
        _saving) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _capturing = true;
      _loading = true;
      _error = null;
      _result = null;
      _captureFlash = false;
      _scanStep = 0;
      _scanProgress = 0;
    });

    try {
      final file = await controller.takePicture();
      if (!mounted) return;

      setState(() {
        _capturing = false;
        _capturedImagePath = file.path;
        _captureFlash = true;
        _cameraStage = 1;
      });

      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _captureFlash = false);

      await _runAnalysis(file.path);
    } catch (_) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() {
        _capturing = false;
        _loading = false;
        _error = 'No se pudo capturar la imagen';
      });
    }
  }

  Future<void> _runAnalysis(String imagePath) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _scanStep = 1;
      _scanProgress = 0.33;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _scanStep = 2;
      _scanProgress = 0.66;
    });

    try {
      final result =
          await widget.services.foodOrchestrator.classifyFromImage(imagePath);
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _loading = false;
          _error =
              'No se detectó ninguna comida. Intenta con mejor iluminación.';
          _cameraStage = 0;
        });
        return;
      }

      final itemWithImage = result.copyWith(imageUrl: imagePath);
      setState(() {
        _loading = false;
        _result = itemWithImage;
        _scanStep = 3;
        _scanProgress = 1.0;
        _cameraStage = 2;
      });
      HapticFeedback.lightImpact();
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error al analizar: $e';
        _cameraStage = 0;
      });
    }
  }

  void _retake() {
    setState(() {
      _cameraStage = 0;
      _result = null;
      _capturedImagePath = null;
      _loading = false;
      _error = null;
    });
    if (_barcodeMode) {
      _barcodeController?.start();
    }
  }

  Future<void> _saveResult(FoodItem item) async {
    if (_saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    await widget.services.trackingUseCases
        .addFoodEntry(mealSlot: _mealSlot, food: item);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _saving = false);
    if (mounted) {
      AppNotifier.success(
          context, '${item.nameEs} agregado en ${_mealSlot.label}');
      Navigator.of(context).maybePop();
    }
  }

  // Handle barcode detection
  void _onBarcodeDetected(barcode.BarcodeCapture capture) async {
    // Evitar escaneos múltiples mientras ya estamos cargando
    if (_loading || _saving) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    HapticFeedback.mediumImpact();
    
    setState(() {
      _loading = true;
      // Detenemos temporalmente el escáner para procesar el código detectado
      _barcodeController?.stop();
    });
    
    try {
      final item = await widget.services.foodOrchestrator.findByBarcode(code);
      
      if (!mounted) return;
      
      if (item != null) {
        setState(() {
          _result = item;
          _cameraStage = 2; // Show the result view!
        });
      } else {
        AppNotifier.error(context, 'Producto no encontrado en la base de datos');
        _barcodeController?.start(); // Resume scanning because we didn't find it
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.error(context, 'Error escaneando: $e');
        _barcodeController?.start();
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ===== SEARCH METHODS =====
  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searchLoading = true;
      _searchResults = const [];
    });
    final results =
        await widget.services.foodOrchestrator.searchFoodInSpanish(q);
    if (!mounted) return;
    setState(() {
      _searchLoading = false;
      _searchResults = results;
    });
  }

  // ===== RECIPE METHODS =====
  Future<void> _doRecipeSearch() async {
    final q = _recipeCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _recipeLoading = true;
      _recipeResults = const [];
    });
    final results =
        await widget.services.foodOrchestrator.searchRecipesInSpanish(q);
    if (!mounted) return;
    setState(() {
      _recipeLoading = false;
      _recipeResults = results;
    });
  }

  // ===== VOICE METHODS =====
  Future<void> _initSpeech() async {
    final ready = await _speech.initialize();
    if (!mounted) return;
    setState(() => _speechReady = ready);
  }

  Future<void> _toggleListening() async {
    if (!_speechReady) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    await _speech.listen(
      localeId: 'es_ES',
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _voiceCtrl.text = result.recognizedWords;
          _voiceCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _voiceCtrl.text.length),
          );
        });
      },
    );
    if (!mounted) return;
    setState(() => _listening = true);
  }

  Future<void> _processVoice() async {
    final input = _voiceCtrl.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _voiceLoading = true;
      _voiceResult = null;
    });

    final results =
        await widget.services.foodOrchestrator.searchFoodInSpanish(input);
    if (!mounted) return;

    if (results.isNotEmpty) {
      final item = results.first;
      await widget.services.trackingUseCases
          .addFoodEntry(mealSlot: _mealSlot, food: item);
      if (!mounted) return;
      setState(() {
        _voiceLoading = false;
        _voiceResult = '${item.nameEs} agregado (${item.nutrition.kcal.toStringAsFixed(0)} kcal)';
      });
      AppNotifier.success(context, '${item.nameEs} agregado');
    } else {
      setState(() {
        _voiceLoading = false;
        _voiceResult = 'No se encontró alimento';
      });
    }
  }

  // ===== SAVE ITEM (Search/Recipe) =====
  Future<void> _saveItem(FoodItem item) async {
    HapticFeedback.mediumImpact();
    await widget.services.trackingUseCases
        .addFoodEntry(mealSlot: _mealSlot, food: item);
    if (!mounted) return;
    AppNotifier.success(
        context, '${item.nameEs} agregado en ${_mealSlot.label}');
  }

  LinearGradient _gradientForSlot(MealSlot slot) {
    switch (slot) {
      case MealSlot.desayuno:
        return NutrifotoColors.desayunoGradient;
      case MealSlot.almuerzo:
        return NutrifotoColors.almuerzoGradient;
      case MealSlot.cena:
        return NutrifotoColors.cenaGradient;
      case MealSlot.once:
        return NutrifotoColors.onceGradient;
      case MealSlot.snack:
        return NutrifotoColors.snackGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NutrifotoColors.bg,
      body: Column(
        children: [
          // Content area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildTabContent(),
            ),
          ),
          // Persistent bottom tab bar
          _CameraBottomTabBar(
            selectedTab: _selectedTab,
            onTabChanged: (index) {
              HapticFeedback.lightImpact();
              setState(() => _selectedTab = index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildCameraTab();
      case 1:
        return _buildRecipesTab();
      case 2:
        return _buildSearchTab();
      case 3:
        return _buildManualTab();
      case 4:
        return _buildVoiceTab();
      default:
        return _buildCameraTab();
    }
  }

  // ===== TAB 0: CAMERA (with food/barcode toggle) =====
  Widget _buildCameraTab() {
    // Show analyzing or result stages
    if (_cameraStage == 1) return _buildAnalyzingView();
    if (_cameraStage == 2) return _buildResultView();

    final topPad = MediaQuery.of(context).padding.top;

    return Stack(
      key: const ValueKey('camera_tab'),
      children: [
        // Camera or barcode scanner
        Positioned.fill(
          child: _barcodeMode
              ? (_barcodeController != null
                  ? barcode.MobileScanner(
                      controller: _barcodeController!,
                      onDetect: _onBarcodeDetected,
                    )
                  : Container(color: Colors.black))
              : (_cameraReady && _cameraController != null)
                  ? CameraPreview(_cameraController!)
                  : _error != null
                      ? Container(
                          color: Colors.black,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 16),
                                  textAlign: TextAlign.center),
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(
                                  NutrifotoColors.primary),
                            ),
                          ),
                        ),
        ),

        // Food scanner area overlay
        if (!_barcodeMode && _cameraReady && _cameraController != null)
          Positioned.fill(
            child: IgnorePointer( // Let taps pass through
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.width * 0.85, // Perfect square
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withAlpha(0xCC), width: 3), // .withAlpha(204) represents .withValues(alpha: 0.8) which is ~204 out of 255
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(0x33), // represents .withValues(alpha: 0.2)
                        spreadRadius: 2,
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: const Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        'Enfoca la comida aquí',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Barcode scanner area overlay
        if (_barcodeMode)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: 200, // Barcode shape rectangle
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(0x11), 
                    border: Border.all(color: NutrifotoColors.primary, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(Icons.qr_code_scanner, color: Colors.white54, size: 64),
                  ),
                ),
              ),
            ),
          ),

        // Top bar
        Positioned(
          top: topPad + 8,
          left: 16,
          right: 16,
          child: Row(
            children: [
              _CircleButton(
                icon: Icons.close,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: _gradientForSlot(_mealSlot),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _mealSlot.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              _CircleButton(
                icon: _flashEnabled ? Icons.flash_on : Icons.flash_off,
                active: _flashEnabled,
                onTap: _toggleFlash,
              ),
            ],
          ),
        ),

        // Food / Barcode toggle
        Positioned(
          top: topPad + 60,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModeToggle(
                    label: '📸 Comida',
                    selected: !_barcodeMode,
                    onTap: _barcodeMode ? _switchToFoodMode : null,
                  ),
                  const SizedBox(width: 4),
                  _ModeToggle(
                    label: '📦 Código',
                    selected: _barcodeMode,
                    onTap: !_barcodeMode ? _switchToBarcodeMode : null,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Capture button (only in food mode)
        if (!_barcodeMode)
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: GestureDetector(
                  onTap: _captureAndAnalyze,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color:
                              NutrifotoColors.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            NutrifotoColors.primary,
                            NutrifotoColors.primarySoft
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Barcode hint
        if (_barcodeMode)
          Positioned(
            bottom: 40,
            left: 40,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Apunta al código de barras del producto',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        if (_captureFlash)
          Container(color: Colors.white, child: const SizedBox.expand()),
      ],
    );
  }

  Widget _buildAnalyzingView() {
    const steps = ['Preparando...', 'Analizando con IA...', 'Completado!'];

    return Container(
      key: const ValueKey('analyzing'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0F25), Color(0xFF151D3A)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: _scanProgress),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return CircularProgressIndicator(
                          value: value,
                          strokeWidth: 6,
                          backgroundColor: NutrifotoColors.surface,
                          valueColor: const AlwaysStoppedAnimation(
                              NutrifotoColors.primary),
                        );
                      },
                    ),
                  ),
                  Text(
                    '${(_scanProgress * 100).toInt()}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                steps[_scanStep.clamp(0, steps.length - 1)],
                key: ValueKey(_scanStep),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: _gradientForSlot(_mealSlot),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Agregando a: ${_mealSlot.label}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    if (_result == null) {
      return Container(
          key: const ValueKey('result_loading'),
          color: Colors.black,
          child: const Center(
              child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation(NutrifotoColors.primary))));
    }

    final item = _result!;

    return Container(
      key: const ValueKey('result'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0F25), Color(0xFF151D3A)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_capturedImagePath != null || (item.imageUrl != null && item.imageUrl!.isNotEmpty))
                Container(
                  height: 260,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: NutrifotoColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _capturedImagePath != null
                        ? Image.file(File(_capturedImagePath!), fit: BoxFit.cover)
                        : Image.network(
                            item.imageUrl!, 
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: NutrifotoColors.surface,
                              child: const Center(
                                child: Icon(Icons.image_not_supported, color: Colors.white54, size: 64),
                              ),
                            ),
                          ),
                  ),
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: NutrifotoColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nameEs,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    if (item.metadata['brand'] != null && item.metadata['brand'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.metadata['brand'].toString(),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _NutrientBadge('Proteína',
                            item.nutrition.proteinG, 'g', const Color(0xFF66BEFF)),
                        _NutrientBadge('Carbos',
                            item.nutrition.carbsG, 'g', const Color(0xFFFFD35F)),
                        _NutrientBadge('Grasas',
                            item.nutrition.fatG, 'g', const Color(0xFFD8C8FF)),
                        _NutrientBadge(
                            'kcal', item.nutrition.kcal, '', Colors.white),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: _saving ? null : _retake,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Retomar',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : () => _saveResult(item),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      Colors.white)))
                          : const Text('Agregar',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== TAB 1: RECIPES =====
  Widget _buildRecipesTab() {
    return Container(
      key: const ValueKey('recipes_tab'),
      color: NutrifotoColors.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTabHeader('Recetas', Icons.menu_book_rounded),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _recipeCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ingrediente (ej. pollo)',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: NutrifotoColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: (_) => _doRecipeSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.restaurant_menu,
                    onTap: _recipeLoading ? null : _doRecipeSearch,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _recipeLoading
                  ? ListView(
                      children: List.generate(
                          4, (_) => const SkeletonListItem()))
                  : _recipeResults.isEmpty
                      ? Center(
                          child: Text('Busca recetas por ingrediente',
                              style: TextStyle(
                                  color: NutrifotoColors.textMuted)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _recipeResults.length,
                          itemBuilder: (ctx, i) =>
                              _FoodListTile(
                                item: _recipeResults[i],
                                onAdd: () => _saveItem(_recipeResults[i]),
                              ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== TAB 2: SEARCH =====
  Widget _buildSearchTab() {
    return Container(
      key: const ValueKey('search_tab'),
      color: NutrifotoColors.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTabHeader('Buscar Alimento', Icons.search_rounded),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar alimento...',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: NutrifotoColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        prefixIcon: const Icon(Icons.search,
                            color: NutrifotoColors.textMuted),
                      ),
                      onSubmitted: (_) => _doSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.search,
                    onTap: _searchLoading ? null : _doSearch,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _searchLoading
                  ? ListView(
                      children: List.generate(
                          5, (_) => const SkeletonListItem()))
                  : _searchResults.isEmpty
                      ? Center(
                          child: Text('Escribe para buscar alimentos',
                              style: TextStyle(
                                  color: NutrifotoColors.textMuted)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _searchResults.length,
                          itemBuilder: (ctx, i) =>
                              _FoodListTile(
                                item: _searchResults[i],
                                onAdd: () => _saveItem(_searchResults[i]),
                              ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== TAB 3: MANUAL =====
  Widget _buildManualTab() {
    return Container(
      key: const ValueKey('manual_tab'),
      color: NutrifotoColors.bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTabHeader('Registro Manual', Icons.edit_note_rounded),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: NutrifotoColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_note_rounded,
                          color: NutrifotoColors.primary, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Registro manual de alimentos',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text('Ingresa datos nutricionales en detalle',
                        style: TextStyle(color: NutrifotoColors.textMuted)),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/manual',
                            arguments: {'mealSlot': _mealSlot});
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Abrir formulario'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== TAB 4: VOICE =====
  Widget _buildVoiceTab() {
    return Container(
      key: const ValueKey('voice_tab'),
      color: NutrifotoColors.bg,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTabHeader('Por Voz', Icons.mic_rounded),
              const SizedBox(height: 24),
              // Mic button
              GestureDetector(
                onTap: _voiceLoading ? null : _toggleListening,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _listening
                          ? [const Color(0xFFFF4D4D), const Color(0xFFFF6B6B)]
                          : [NutrifotoColors.primary, NutrifotoColors.primarySoft],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_listening
                                ? const Color(0xFFFF4D4D)
                                : NutrifotoColors.primary)
                            .withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _listening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _listening ? 'Escuchando...' : 'Toca para hablar',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              // Text input
              TextField(
                controller: _voiceCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'O escribe lo que comiste...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: NutrifotoColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _voiceLoading ? null : _processVoice,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(
                      _voiceLoading ? 'Procesando...' : 'Analizar y agregar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              if (_voiceResult != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NutrifotoColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: NutrifotoColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(_voiceResult!,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===== SHARED WIDGETS =====
  Widget _buildTabHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 4),
      child: Row(
        children: [
          _CircleButton(
            icon: Icons.close,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Icon(icon, color: NutrifotoColors.primary, size: 24),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: _gradientForSlot(_mealSlot),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(_mealSlot.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ===== REUSABLE PRIVATE WIDGETS =====

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active
              ? NutrifotoColors.primary
              : Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: NutrifotoColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeToggle({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? NutrifotoColors.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [NutrifotoColors.primary, NutrifotoColors.primarySoft],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _CameraBottomTabBar extends StatelessWidget {
  final int selectedTab;
  final Function(int) onTabChanged;

  const _CameraBottomTabBar({
    required this.selectedTab,
    required this.onTabChanged,
  });

  static const _tabs = <(IconData, String)>[
    (Icons.camera_alt_rounded, 'Escanear'),
    (Icons.menu_book_rounded, 'Recetas'),
    (Icons.search_rounded, 'Buscar'),
    (Icons.edit_note_rounded, 'Lista'),
    (Icons.mic_rounded, 'Voz'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF0080F2A),
        border: Border(
          top: BorderSide(
            color: NutrifotoColors.primary.withValues(alpha: 0.15),
          ),
        ),
      ),
      padding: EdgeInsets.fromLTRB(8, 10, 8, 10 + bottomPad),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_tabs.length, (index) {
          final (icon, label) = _tabs[index];
          final isSelected = index == selectedTab;

          return GestureDetector(
            onTap: () => onTabChanged(index),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? NutrifotoColors.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: isSelected ? 26 : 22,
                      color: isSelected
                          ? NutrifotoColors.primary
                          : Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? NutrifotoColors.primary
                              : Colors.white.withValues(alpha: 0.5))),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FoodListTile extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onAdd;

  const _FoodListTile({required this.item, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NutrifotoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: NutrifotoColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.restaurant_rounded,
                color: NutrifotoColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nameEs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                    '${item.nutrition.kcal.toStringAsFixed(0)} kcal  •  P${item.nutrition.proteinG.toStringAsFixed(0)}g  C${item.nutrition.carbsG.toStringAsFixed(0)}g  G${item.nutrition.fatG.toStringAsFixed(0)}g',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    NutrifotoColors.primary,
                    NutrifotoColors.primarySoft
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientBadge extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _NutrientBadge(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(1)}$unit',
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
