import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../application/app_services.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_notifier.dart';
import '../widgets/feedback_widgets.dart';
import '../widgets/nutrifoto_ui.dart';

enum _BarcodeStage { camera, analyzing, result }

class ScannerBarcodeScreen extends StatefulWidget {
  final AppServices services;

  const ScannerBarcodeScreen({super.key, required this.services});

  @override
  State<ScannerBarcodeScreen> createState() => _ScannerBarcodeScreenState();
}

class _ScannerBarcodeScreenState extends State<ScannerBarcodeScreen> {
  final _scannerController = MobileScannerController();
  bool _loading = false;
  bool _saving = false;
  bool _flashEnabled = false;
  bool _autoStartDone = false;
  bool _scanHandled = false;
  int _scanStep = 0;
  double _scanProgress = 0;
  MealSlot _mealSlot = MealSlot.almuerzo;
  bool _argsApplied = false;
  _BarcodeStage _stage = _BarcodeStage.camera;
  String? _barcodeValue;
  FoodItem? _result;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) {
      return;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['mealSlot'] is MealSlot) {
      _mealSlot = args['mealSlot'] as MealSlot;
    }
    _argsApplied = true;

    if (!_autoStartDone) {
      _autoStartDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startScanner();
      });
    }
  }

  Future<void> _saveResult() async {
    final item = _result;
    if (item == null || _saving) {
      return;
    }

    setState(() => _saving = true);
    await widget.services.trackingUseCases.addFoodEntry(
      mealSlot: _mealSlot,
      food: item,
    );

    if (!mounted) {
      return;
    }

    setState(() => _saving = false);
    AppNotifier.success(
      context,
      '${item.nameEs} agregado en ${_mealSlot.label}',
    );
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _startScanner() async {
    try {
      _scanHandled = false;
      await _scannerController.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _error = null;
        _stage = _BarcodeStage.camera;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'No se pudo iniciar la camara para escanear';
      });
    }
  }

  Future<void> _toggleFlash() async {
    await _scannerController.toggleTorch();
    if (!mounted) {
      return;
    }
    setState(() {
      _flashEnabled = !_flashEnabled;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanHandled || _loading || _saving || _stage != _BarcodeStage.camera) {
      return;
    }

    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstWhere((v) => v.trim().isNotEmpty, orElse: () => '')
        .trim();

    if (code.isEmpty) {
      return;
    }

    _scanHandled = true;
    await _scannerController.stop();

    setState(() {
      _stage = _BarcodeStage.analyzing;
      _barcodeValue = code;
      _loading = true;
      _error = null;
      _result = null;
      _scanStep = 0;
      _scanProgress = 0;
    });

    await _runLookupPipeline(code);
  }

  Future<void> _runLookupPipeline(String barcode) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() {
      _scanStep = 1;
      _scanProgress = 0.33;
    });

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _scanStep = 2;
      _scanProgress = 0.66;
    });

    final item = await widget.services.foodOrchestrator.findByBarcode(barcode);

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    if (item == null) {
      setState(() {
        _scanStep = 3;
        _scanProgress = 1;
        _loading = false;
        _error = 'Producto no encontrado. Intenta otro codigo.';
        _stage = _BarcodeStage.camera;
      });
      await _startScanner();
      return;
    }

    setState(() {
      _scanStep = 3;
      _scanProgress = 1;
      _loading = false;
      _result = item;
      _stage = _BarcodeStage.result;
    });
  }

  Future<void> _retake() async {
    if (_saving || _loading) {
      return;
    }

    setState(() {
      _result = null;
      _error = null;
      _barcodeValue = null;
      _stage = _BarcodeStage.camera;
    });

    await _startScanner();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_stage == _BarcodeStage.camera)
            _BarcodeCameraStageView(
              controller: _scannerController,
              error: _error,
              mealSlot: _mealSlot,
              flashEnabled: _flashEnabled,
              onClose: () => Navigator.of(context).maybePop(),
              onToggleFlash: _toggleFlash,
              onDetect: _onDetect,
            ),
          if (_stage == _BarcodeStage.analyzing)
            _BarcodeAnalyzingStageView(
              step: _scanStep,
              progress: _scanProgress,
              mealSlot: _mealSlot,
              barcodeValue: _barcodeValue,
            ),
          if (_stage == _BarcodeStage.result)
            _BarcodeResultStageView(
              item: _result,
              barcodeValue: _barcodeValue,
              mealSlot: _mealSlot,
              saving: _saving,
              onAccept: _saveResult,
              onRetake: _retake,
            ),
        ],
      ),
    );
  }
}

class _BarcodeCameraStageView extends StatefulWidget {
  final MobileScannerController controller;
  final String? error;
  final MealSlot mealSlot;
  final bool flashEnabled;
  final VoidCallback onClose;
  final VoidCallback onToggleFlash;
  final ValueChanged<BarcodeCapture> onDetect;

  const _BarcodeCameraStageView({
    required this.controller,
    required this.error,
    required this.mealSlot,
    required this.flashEnabled,
    required this.onClose,
    required this.onToggleFlash,
    required this.onDetect,
  });

  @override
  State<_BarcodeCameraStageView> createState() =>
      _BarcodeCameraStageViewState();
}

class _BarcodeCameraStageViewState extends State<_BarcodeCameraStageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth - 40, 340.0);
        final height = math.max(130.0, width * 0.44);
        final top = math.max(170.0, constraints.maxHeight * 0.32);
        final scanRect = Rect.fromLTWH(
          (constraints.maxWidth - width) / 2,
          top,
          width,
          height,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: widget.controller,
              onDetect: widget.onDetect,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.48),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.62),
                  ],
                  stops: const [0, 0.38, 1],
                ),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarcodeScannerOverlayPainter(scanRect: scanRect),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TopRoundIconButton(
                      icon: Icons.close,
                      onTap: widget.onClose,
                    ),
                    _TopRoundIconButton(
                      icon: widget.flashEnabled
                          ? Icons.flash_on
                          : Icons.flash_off,
                      onTap: widget.onToggleFlash,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 98,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Escanea el codigo de barras',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Centra las lineas en el area iluminada',
                        style: TextStyle(
                          color: Color(0xFFC8CFDF),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: scanRect,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF63D7FF),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF63D7FF,
                          ).withValues(alpha: 0.34),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _scanLineController,
                      builder: (context, child) {
                        final y =
                            6 +
                            ((scanRect.height - 12) *
                                _scanLineController.value);
                        return Stack(
                          children: [
                            Positioned(
                              left: 10,
                              right: 10,
                              top: y,
                              child: Container(
                                height: 2.4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Color(0xFF8EE8FF),
                                      Color(0xFF8EE8FF),
                                      Colors.transparent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF8EE8FF,
                                      ).withValues(alpha: 0.45),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const _FrameCorner(alignment: Alignment.topLeft),
                  const _FrameCorner(alignment: Alignment.topRight),
                  const _FrameCorner(alignment: Alignment.bottomLeft),
                  const _FrameCorner(alignment: Alignment.bottomRight),
                ],
              ),
            ),
            Positioned(
              top: scanRect.bottom + 12,
              left: 0,
              right: 0,
              child: const Center(
                child: Text(
                  'Tip: evita reflejos para detectar mas rapido',
                  style: TextStyle(
                    color: Color(0xFFCDD7E8),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 30,
              child: Column(
                children: [
                  if (widget.error != null) ...[
                    ErrorBlock(message: widget.error!),
                    const SizedBox(height: 10),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.52),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      'Se guardara en ${widget.mealSlot.label}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFBBE9FF),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BarcodeScannerOverlayPainter extends CustomPainter {
  final Rect scanRect;

  const _BarcodeScannerOverlayPainter({required this.scanRect});

  @override
  void paint(Canvas canvas, Size size) {
    final layerBounds = Offset.zero & size;
    final cutout = RRect.fromRectAndRadius(scanRect, const Radius.circular(20));

    canvas.saveLayer(layerBounds, Paint());
    canvas.drawRect(
      layerBounds,
      Paint()..color = Colors.black.withValues(alpha: 0.42),
    );
    canvas.drawRRect(cutout, Paint()..blendMode = BlendMode.clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BarcodeScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanRect != scanRect;
  }
}

class _FrameCorner extends StatelessWidget {
  final Alignment alignment;

  const _FrameCorner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    final left = alignment.x < 0;
    final top = alignment.y < 0;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            border: Border(
              top: top
                  ? const BorderSide(color: Color(0xFFD8FAFF), width: 3)
                  : BorderSide.none,
              bottom: top
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xFFD8FAFF), width: 3),
              left: left
                  ? const BorderSide(color: Color(0xFFD8FAFF), width: 3)
                  : BorderSide.none,
              right: left
                  ? BorderSide.none
                  : const BorderSide(color: Color(0xFFD8FAFF), width: 3),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopRoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopRoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _BarcodeAnalyzingStageView extends StatefulWidget {
  final int step;
  final double progress;
  final MealSlot mealSlot;
  final String? barcodeValue;

  const _BarcodeAnalyzingStageView({
    required this.step,
    required this.progress,
    required this.mealSlot,
    required this.barcodeValue,
  });

  @override
  State<_BarcodeAnalyzingStageView> createState() =>
      _BarcodeAnalyzingStageViewState();
}

class _BarcodeAnalyzingStageViewState extends State<_BarcodeAnalyzingStageView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ambientController,
      builder: (context, child) {
        final t = _ambientController.value;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF171038), Color(0xFF090B1B), Color(0xFF130729)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 90 - (t * 14),
                left: -26,
                child: _GlowOrb(
                  size: 150 + (t * 24),
                  color: const Color(0xFF8F62FF),
                ),
              ),
              Positioned(
                right: -34,
                bottom: 120 - (t * 18),
                child: _GlowOrb(
                  size: 180 + (t * 30),
                  color: const Color(0xFF4E8AFF),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Color(0xFF8F62FF),
                          size: 52,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Analizando codigo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 33,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Guardaremos esto en ${widget.mealSlot.label}.',
                        style: const TextStyle(
                          color: Color(0xFFC3C9DF),
                          fontSize: 17,
                        ),
                      ),
                      if (widget.barcodeValue != null &&
                          widget.barcodeValue!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Codigo: ${widget.barcodeValue}',
                          style: const TextStyle(
                            color: Color(0xFFA69BCA),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: Colors.black.withValues(alpha: 0.24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          children: [
                            _AnalyzeStepTile(
                              label: 'Leyendo codigo',
                              active: widget.step == 1,
                              done: widget.step > 1,
                            ),
                            const SizedBox(height: 14),
                            _AnalyzeStepTile(
                              label: 'Consultando base',
                              active: widget.step == 2,
                              done: widget.step > 2,
                            ),
                            const SizedBox(height: 14),
                            _AnalyzeStepTile(
                              label: 'Preparando resultado',
                              active: widget.step == 3,
                              done: widget.step > 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Progreso',
                            style: TextStyle(
                              color: Color(0xFFC6CADA),
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '${(widget.progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Color(0xFF9D7DFF),
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: widget.progress,
                          minHeight: 12,
                          backgroundColor: Colors.white.withValues(alpha: 0.14),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF8F62FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.3), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _AnalyzeStepTile extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;

  const _AnalyzeStepTile({
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? const Color(0xFF6DF3AE)
        : active
        ? const Color(0xFF9B77FF)
        : const Color(0xFF697089);
    final bg = done
        ? const Color(0xFF6DF3AE).withValues(alpha: 0.2)
        : active
        ? const Color(0xFF9B77FF).withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.06);
    final icon = done
        ? Icons.check_circle
        : active
        ? Icons.timelapse
        : Icons.radio_button_unchecked;

    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: done || active ? Colors.white : const Color(0xFF8D93A9),
              fontSize: active ? 22 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BarcodeResultStageView extends StatelessWidget {
  final FoodItem? item;
  final String? barcodeValue;
  final MealSlot mealSlot;
  final bool saving;
  final VoidCallback onAccept;
  final VoidCallback onRetake;

  const _BarcodeResultStageView({
    required this.item,
    required this.barcodeValue,
    required this.mealSlot,
    required this.saving,
    required this.onAccept,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final product = item;
    if (product == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AnimatedScreenBody(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HeroPanel(
            title: 'Producto detectado',
            subtitle: 'Revisa los datos y confirma para guardar',
            gradient: NutrifotoColors.scannerGradient,
          ),
          const SizedBox(height: 14),
          _FoodResultCard(
            item: product,
            barcodeValue: barcodeValue,
            mealSlot: mealSlot,
            saving: saving,
            onAccept: onAccept,
            onRetake: onRetake,
          ),
        ],
      ),
    );
  }
}

class _FoodResultCard extends StatelessWidget {
  final FoodItem item;
  final String? barcodeValue;
  final MealSlot mealSlot;
  final VoidCallback onAccept;
  final VoidCallback onRetake;
  final bool saving;

  const _FoodResultCard({
    required this.item,
    required this.barcodeValue,
    required this.mealSlot,
    required this.onAccept,
    required this.onRetake,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = item.imageUrl;
    ImageProvider? provider;
    if (imagePath != null && imagePath.isNotEmpty) {
      provider = imagePath.startsWith('http')
          ? NetworkImage(imagePath)
          : FileImage(File(imagePath));
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image(image: provider, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(item.nameEs, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Se guardara en ${mealSlot.label}',
            style: const TextStyle(
              color: Color(0xFF8F62FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Fuente: ${item.source.name}',
            style: const TextStyle(color: NutrifotoColors.textMuted),
          ),
          if (barcodeValue != null && barcodeValue!.isNotEmpty)
            Text(
              'Codigo: $barcodeValue',
              style: const TextStyle(color: NutrifotoColors.textMuted),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MacroChip(
                label: 'Calorias',
                value: '${item.nutrition.kcal.toStringAsFixed(0)} kcal',
              ),
              _MacroChip(
                label: 'Proteinas',
                value: '${item.nutrition.proteinG.toStringAsFixed(1)} g',
              ),
              _MacroChip(
                label: 'Carbohidratos',
                value: '${item.nutrition.carbsG.toStringAsFixed(1)} g',
              ),
              _MacroChip(
                label: 'Grasas',
                value: '${item.nutrition.fatG.toStringAsFixed(1)} g',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: saving ? null : onAccept,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(saving ? 'Guardando...' : 'Aceptar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : onRetake,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Volver a tomar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;

  const _MacroChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer),
      ),
    );
  }
}
