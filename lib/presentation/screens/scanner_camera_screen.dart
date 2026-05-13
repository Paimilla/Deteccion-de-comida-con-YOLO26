import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io show File;
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

  // Sugerencias estáticas para carga instantánea
  static final List<FoodItem> _staticRecipeSuggestions = [
    const FoodItem(
      source: FoodSource.localChile,
      itemId: 'st_pollo_cam',
      nameEs: 'Pechuga de Pollo a la Plancha',
      portion: Portion(amount: 150, unit: 'g'),
      nutrition: Nutrition(kcal: 247, proteinG: 46, carbsG: 0.5, fatG: 5.5),
      imageUrl: 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?q=80&w=400&auto=format&fit=crop',
      metadata: {
        'short_description_es': 'Tierna pechuga de pollo asada con un toque de especias.',
        'instructions_es': '1. Sazonar la pechuga con sal, pimienta y tus especias favoritas.\n2. Calentar una sartén a fuego medio con un poco de aceite.\n3. Cocinar la pechuga 6-8 minutos por lado hasta que esté dorada.\n4. Dejar reposar 2 minutos antes de cortar.'
      },
    ),
    const FoodItem(
      source: FoodSource.localChile,
      itemId: 'st_salmon_cam',
      nameEs: 'Salmón con Espárragos',
      portion: Portion(amount: 200, unit: 'g'),
      nutrition: Nutrition(kcal: 380, proteinG: 40, carbsG: 2, fatG: 22),
      imageUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?q=80&w=400&auto=format&fit=crop',
      metadata: {
        'short_description_es': 'Filete de salmón sellado con vegetales verdes al dente.',
        'instructions_es': '1. Limpiar los espárragos retirando la base fibrosa.\n2. Sellar el salmón en una sartén caliente con piel hacia abajo.\n3. Agregar los espárragos al mismo tiempo.\n4. Cocinar por 5 minutos y dar vuelta al salmón.'
      },
    ),
    const FoodItem(
      source: FoodSource.localChile,
      itemId: 'st_ensalada_cam',
      nameEs: 'Ensalada César con Pollo',
      portion: Portion(amount: 300, unit: 'g'),
      nutrition: Nutrition(kcal: 420, proteinG: 25, carbsG: 15, fatG: 28),
      imageUrl: 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?q=80&w=400&auto=format&fit=crop',
      metadata: {
        'short_description_es': 'Receta clásica con aderezo ligero y crutones integrales.',
        'instructions_es': '1. Cortar la lechuga en trozos medianos.\n2. Preparar el pollo a la plancha y cortarlo en tiras.\n3. Mezclar con aderezo César bajo en grasa.\n4. Añadir crutones y queso parmesano al gusto.'
      },
    ),
  ];

  late List<FoodItem> _recipeFeaturedItems;

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

    _recipeFeaturedItems = List.from(_staticRecipeSuggestions);
    _initSpeech();
    _loadInitialRecipes();
  }

  Future<void> _loadInitialRecipes() async {
    try {
      final items = await widget.services.foodOrchestrator.searchRecipesInSpanish('saludable');
      if (mounted && items.isNotEmpty) {
        setState(() {
          _recipeFeaturedItems = [..._staticRecipeSuggestions, ...items.take(5)].toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recipes suggestions: $e');
    }
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
    // First handle flash and dispose
    if (_flashEnabled) {
      try { await _cameraController?.setFlashMode(FlashMode.off); } catch (_) {}
    }
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
    if (_flashEnabled) {
      await _barcodeController?.toggleTorch(); // Si estaba prendido, toggle lo apaga
    }
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
    HapticFeedback.lightImpact();

    if (_barcodeMode) {
      if (_barcodeController == null) return;
      await _barcodeController!.toggleTorch();
      setState(() => _flashEnabled = !_flashEnabled);
      return;
    }

    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    
    try {
      final newMode = _flashEnabled ? FlashMode.off : FlashMode.torch;
      await controller.setFlashMode(newMode);
      setState(() => _flashEnabled = !_flashEnabled);
    } catch (e) {
      debugPrint('Error toggling flash: $e');
    }
  }

  Future<void> _captureAndAnalyze() async {
    final controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        _loading ||
        _saving) {
      return;
    }

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
                        ? (kIsWeb
                            ? Image.network(_capturedImagePath!, fit: BoxFit.cover)
                            : Image.file(io.File(_capturedImagePath!), fit: BoxFit.cover))
                        : NutrifotoImage(
                            imageUrl: item.imageUrl,
                            name: item.nameEs,
                            size: 64,
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
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CircularMacro(
                          label: 'Calorías',
                          value: item.nutrition.kcal,
                          unit: 'kcal',
                          target: 2200,
                          color: Colors.orange,
                        ),
                        _CircularMacro(
                          label: 'Prot',
                          value: item.nutrition.proteinG,
                          unit: 'g',
                          target: 176,
                          color: Colors.blue,
                        ),
                        _CircularMacro(
                          label: 'Carbs',
                          value: item.nutrition.carbsG,
                          unit: 'g',
                          target: 231,
                          color: Colors.green,
                        ),
                        _CircularMacro(
                          label: 'Grasa',
                          value: item.nutrition.fatG,
                          unit: 'g',
                          target: 63,
                          color: Colors.red,
                        ),
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
            _buildTabHeader('Explorar Recetas', Icons.menu_book_rounded),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _recipeCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ej: ensalada, pasta, pollo...',
                        hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: NutrifotoColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        prefixIcon: const Icon(Icons.restaurant_menu_rounded,
                            color: NutrifotoColors.textMuted),
                      ),
                      onSubmitted: (_) => _doRecipeSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.search,
                    onTap: _recipeLoading ? null : _doRecipeSearch,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _recipeLoading
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: List.generate(3, (_) => const SkeletonListItem()))
                  : _recipeResults.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Sugerencias Premium',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ..._recipeFeaturedItems.map((item) => _RecipeResultCard(
                                  item: item,
                                  onTap: () => _showFoodDetail(item),
                                )),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _recipeResults.length,
                          itemBuilder: (ctx, i) =>
                              _RecipeResultCard(
                                item: _recipeResults[i],
                                onTap: () => _showFoodDetail(_recipeResults[i]),
                              ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFoodDetail(FoodItem item) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeDetailSheetLocal(
        item: item,
        mealSlot: _mealSlot,
        services: widget.services,
        onSave: _saveResult,
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
                                onTap: () => _showFoodDetail(_searchResults[i]),
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
  final VoidCallback onTap;

  const _FoodListTile({required this.item, required this.onTap});

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: NutrifotoColors.primary.withValues(alpha: 0.15),
                ),
                child: NutrifotoImage(
                  imageUrl: item.imageUrl,
                  name: item.nameEs,
                  size: 24,
                ),
              ),
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
                    item.metadata['short_description_es'] ?? 'Opción equilibrada y nutritiva.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 2),
                  Text(
                      '${item.nutrition.kcal.toStringAsFixed(0)} kcal  •  P${item.nutrition.proteinG.toStringAsFixed(0)}g  C${item.nutrition.carbsG.toStringAsFixed(0)}g  G${item.nutrition.fatG.toStringAsFixed(0)}g',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class _RecipeResultCard extends StatelessWidget {
  final FoodItem item;
  final VoidCallback onTap;

  const _RecipeResultCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: NutrifotoColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: AspectRatio(
                    aspectRatio: 1.4,
                    child: NutrifotoImage(
                      imageUrl: item.imageUrl,
                      name: item.nameEs,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: NutrifotoColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${item.nutrition.kcal.round()} Kcal',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nameEs,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white, letterSpacing: -0.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.metadata['short_description_es'] ?? 'Receta balanceada y nutritiva ideal para tu plan diario.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MacroResultMini(label: 'PROT', value: item.nutrition.proteinG, target: 176, color: Colors.blue),
                      _MacroResultMini(label: 'CARBS', value: item.nutrition.carbsG, target: 231, color: Colors.green),
                      _MacroResultMini(label: 'GRASAS', value: item.nutrition.fatG, target: 63, color: Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroResultMini extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;

  const _MacroResultMini({
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value / target).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 4,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Text(
              '${(percent * 100).toInt()}%',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.38),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.round()}g',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _RecipeDetailSheetLocal extends StatefulWidget {
  final FoodItem item;
  final MealSlot mealSlot;
  final AppServices services;
  final Function(FoodItem) onSave;
  const _RecipeDetailSheetLocal({required this.item, required this.mealSlot, required this.services, required this.onSave});
  @override
  State<_RecipeDetailSheetLocal> createState() => _RecipeDetailSheetLocalState();
}

class _RecipeDetailSheetLocalState extends State<_RecipeDetailSheetLocal> {
  late double _grams;
  late double _portions;
  bool _isGramsMode = false;
  String? _instructionsEs;
  bool _loadingInstructions = false;

  @override
  void initState() {
    super.initState();
    _grams = widget.item.portion.amount;
    _portions = 1.0;
    _loadInstructions();
  }

  Future<void> _loadInstructions() async {
    // Si ya tenemos instrucciones en español en el metadata (estáticos), las usamos de inmediato
    if (widget.item.metadata['instructions_es'] != null) {
      setState(() {
        _instructionsEs = widget.item.metadata['instructions_es'];
        _loadingInstructions = false;
      });
      return;
    }

    if (widget.item.source != FoodSource.spoonacular) {
      // Intentar generar con Gemini si no es de Spoonacular
      setState(() => _loadingInstructions = true);
      try {
        final aiInstructions = await widget.services.geminiNlpService.generateRecipeInstructions(widget.item.nameEs);
        if (mounted) {
          setState(() {
            _instructionsEs = aiInstructions;
            _loadingInstructions = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loadingInstructions = false);
      }
      return;
    }
    
    setState(() => _loadingInstructions = true);
    try {
      final updatedItem = await widget.services.foodOrchestrator.translateRecipeDetails(widget.item);
      if (mounted) {
        setState(() {
          _instructionsEs = updatedItem.metadata['instructions_es'];
          _loadingInstructions = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingInstructions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double currentGrams = _isGramsMode ? _grams : _portions * widget.item.portion.amount;
    final ratio = currentGrams / widget.item.portion.amount;
    final kcal = widget.item.nutrition.kcal * ratio;
    final protein = widget.item.nutrition.proteinG * ratio;
    final carbs = widget.item.nutrition.carbsG * ratio;
    final fat = widget.item.nutrition.fatG * ratio;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.98,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
            color: NutrifotoColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(28),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 32),
            ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                    aspectRatio: 1.5,
                    child: NutrifotoImage(imageUrl: widget.item.imageUrl, name: widget.item.nameEs))),
            const SizedBox(height: 32),
            Text(widget.item.nameEs, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, height: 1.0)),
            const SizedBox(height: 8),
            Text(
              widget.item.metadata['short_description_es'] ?? 'Una opción nutritiva para tu registro diario.',
              style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 40),
            
            // Mode Switcher
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Expanded(child: _ToggleBtn(label: 'PORCIONES', selected: !_isGramsMode, onTap: () => setState(() => _isGramsMode = false))),
                  Expanded(child: _ToggleBtn(label: 'GRAMOS', selected: _isGramsMode, onTap: () => setState(() => _isGramsMode = true))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_isGramsMode) ...[
              Text('Cantidad: ${_grams.round()} g', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: NutrifotoColors.primary)),
              Slider(value: _grams, min: 10, max: 1000, divisions: 99, activeColor: NutrifotoColors.primary, onChanged: (v) => setState(() => _grams = v)),
            ] else ...[
              Text('Porciones: ${_portions.toStringAsFixed(1)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: NutrifotoColors.accentBlue)),
              Slider(value: _portions, min: 0.5, max: 8.0, divisions: 15, activeColor: NutrifotoColors.accentBlue, onChanged: (v) => setState(() => _portions = v)),
            ],
            const SizedBox(height: 40),
            
            // Macro Info con Círculos de Progreso
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CircularMacro(
                    label: 'Calorías',
                    value: kcal,
                    unit: 'kcal',
                    target: 2200,
                    color: Colors.orange,
                  ),
                  _CircularMacro(
                    label: 'Prot',
                    value: protein,
                    unit: 'g',
                    target: 176,
                    color: Colors.blue,
                  ),
                  _CircularMacro(
                    label: 'Carbs',
                    value: carbs,
                    unit: 'g',
                    target: 231,
                    color: Colors.green,
                  ),
                  _CircularMacro(
                    label: 'Grasa',
                    value: fat,
                    unit: 'g',
                    target: 63,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            const Text('PASOS DE PREPARACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: NutrifotoColors.primary, letterSpacing: 1.0)),
            const SizedBox(height: 16),
            if (_loadingInstructions)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2, color: NutrifotoColors.primary)))
            else if (_instructionsEs != null)
              ..._instructionsEs!
                  .replaceAll(RegExp(r'<[^>]*>'), '')
                  .split(RegExp(r'\.(?=\s|[A-Z])|\n|;'))
                  .where((s) => s.trim().length > 3)
                  .map((s) => s.trim())
                  .toList()
                  .asMap()
                  .entries
                  .map((e) => _PreparationStepLocal(number: e.key + 1, text: e.value.endsWith('.') ? e.value : '${e.value}.'))
            else
              const Text('1. Preparar los ingredientes base.\n2. Cocinar siguiendo las indicaciones nutricionales.\n3. Servir y disfrutar de forma saludable.', style: TextStyle(color: Colors.white60, height: 1.6)),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton(
                onPressed: () {
                  final finalItem = FoodItem(
                    source: widget.item.source,
                    itemId: widget.item.itemId,
                    nameEs: widget.item.nameEs,
                    portion: Portion(amount: currentGrams, unit: 'g'),
                    nutrition: Nutrition(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat),
                    imageUrl: widget.item.imageUrl,
                  );
                  widget.onSave(finalItem);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(backgroundColor: NutrifotoColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text('REGISTRAR COMIDA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _ToggleBtn({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: selected ? NutrifotoColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontWeight: FontWeight.w800, fontSize: 12))),
      ),
    );
  }
}

class _CircularMacro extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double target;
  final Color color;

  const _CircularMacro({
    required this.label,
    required this.value,
    required this.unit,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value / target).clamp(0.0, 1.0);
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 5,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            Text(
              '${(percent * 100).toInt()}%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${value.round()}$unit',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _PreparationStepLocal extends StatelessWidget {
  final int number;
  final String text;
  const _PreparationStepLocal({required this.number, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(color: NutrifotoColors.primary, shape: BoxShape.circle),
            child: Center(child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }
}
