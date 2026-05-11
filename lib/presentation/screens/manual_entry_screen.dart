import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/nutrifoto_ui.dart';

class ManualEntryScreen extends StatefulWidget {
  final AppServices services;

  const ManualEntryScreen({super.key, required this.services});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final _nameCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();

  MealSlot _mealSlot = MealSlot.almuerzo;
  bool _argsApplied = false;
  bool _photoLaunchDone = false;
  bool _saving = false;
  XFile? _selectedPhoto;
  ImageSource? _initialPhotoSource;
  late final AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6200),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) {
      return;
    }

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (args['mealSlot'] is MealSlot) {
        _mealSlot = args['mealSlot'] as MealSlot;
      }
      if (args['photoSource'] is String) {
        final source = args['photoSource'] as String;
        _initialPhotoSource = source == 'camera'
            ? ImageSource.camera
            : ImageSource.gallery;
      }
    }

    _argsApplied = true;

    if (!_photoLaunchDone && _initialPhotoSource != null) {
      _photoLaunchDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickPhoto(_initialPhotoSource!);
      });
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 88,
    );

    if (!mounted || picked == null) {
      return;
    }

    setState(() => _selectedPhoto = picked);
  }

  double? _parseNumber(String raw) {
    return double.tryParse(raw.replaceAll(',', '.').trim());
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    final kcal = _parseNumber(_kcalCtrl.text);
    final protein = _parseNumber(_proteinCtrl.text);
    final carbs = _parseNumber(_carbsCtrl.text);
    final fat = _parseNumber(_fatCtrl.text);
    if (kcal == null || protein == null || carbs == null || fat == null) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    final food = FoodItem(
      source: FoodSource.unknown,
      itemId: DateTime.now().millisecondsSinceEpoch.toString(),
      nameEs: _nameCtrl.text.trim(),
      portion: const Portion(amount: 100, unit: 'g'),
      nutrition: Nutrition(
        kcal: kcal,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      ),
      imageUrl: _selectedPhoto?.path,
      metadata: {
        'created_from': 'manual_entry',
        'has_photo': _selectedPhoto != null,
      },
    );

    try {
      await widget.services.trackingUseCases.addFoodEntry(
        mealSlot: _mealSlot,
        food: food,
      );

      if (!mounted) {
        return;
      }

      HapticFeedback.lightImpact(); // Success feedback
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro guardado correctamente')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) {
        return;
      }
      HapticFeedback.heavyImpact(); // Error feedback
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro Manual')),
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.hoy),
      body: AnimatedScreenBody(
        child: Stack(
          children: [
            Positioned.fill(
              child: _AnimatedManualBackground(
                animation: _backgroundController,
              ),
            ),
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const HeroPanel(
                    title: 'Agregar comida manual',
                    subtitle:
                        'Completa datos nutricionales y adjunta foto opcional',
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedPhoto == null
                                    ? 'Sin foto'
                                    : 'Foto seleccionada',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            if (_selectedPhoto != null)
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _selectedPhoto = null),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Quitar'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: double.infinity,
                          height: MediaQuery.sizeOf(context).height * 0.22,
                          constraints: const BoxConstraints(
                            minHeight: 150,
                            maxHeight: 220,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: _selectedPhoto == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.restaurant, size: 36),
                                    SizedBox(height: 8),
                                    Text('Agrega una foto de tu comida'),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.file(
                                    File(_selectedPhoto!.path),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          'No se pudo cargar la imagen',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickPhoto(ImageSource.camera),
                                icon: const Icon(Icons.photo_camera_outlined),
                                label: const Text('Camara'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _pickPhoto(ImageSource.gallery),
                                icon: const Icon(Icons.photo_library_outlined),
                                label: const Text('Galeria'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del alimento',
                              prefixIcon: Icon(Icons.fastfood_outlined),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? 'Ingresa nombre'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _numberField(
                            _kcalCtrl,
                            'Calorias (kcal)',
                            icon: Icons.local_fire_department_outlined,
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            _proteinCtrl,
                            'Proteinas (g)',
                            icon: Icons.fitness_center,
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            _carbsCtrl,
                            'Carbohidratos (g)',
                            icon: Icons.grain_outlined,
                          ),
                          const SizedBox(height: 8),
                          _numberField(
                            _fatCtrl,
                            'Grasas (g)',
                            icon: Icons.opacity_outlined,
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white70,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(
                                _saving ? 'Guardando...' : 'Guardar comida',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Campo requerido';
        }
        if (_parseNumber(value) == null) {
          return 'Numero invalido';
        }
        return null;
      },
    );
  }
}

class _AnimatedManualBackground extends StatelessWidget {
  final Animation<double> animation;

  const _AnimatedManualBackground({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final topOffset = math.sin(t * math.pi * 2) * 24;
        final bottomOffset = math.cos(t * math.pi * 2) * 20;
        final midOffset = math.sin((t * math.pi * 2) + 1.2) * 18;
        final shimmerOpacity = 0.08 + (math.sin(t * math.pi * 2) * 0.04);

        final surface = Theme.of(context).colorScheme.surface;
        final topColor = Color.lerp(
          surface,
          const Color(0xFF0E2A3F).withValues(alpha: 0.35),
          0.45 + (t * 0.2),
        )!;
        final midColor = Color.lerp(
          surface,
          const Color(0xFF182B58).withValues(alpha: 0.32),
          0.35 + ((1 - t) * 0.22),
        )!;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [topColor, midColor, surface],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -110 + topOffset,
                right: -80,
                child: _BgOrb(
                  size: 250,
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.22),
                ),
              ),
              Positioned(
                left: -90,
                bottom: -120 + bottomOffset,
                child: _BgOrb(
                  size: 300,
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                ),
              ),
              Positioned(
                top: 220 + midOffset,
                right: 40,
                child: _BgOrb(
                  size: 170,
                  color: const Color(0xFF34D399).withValues(alpha: 0.15),
                ),
              ),
              Positioned(
                top: -80 + (topOffset * 0.7),
                left: -120,
                child: Transform.rotate(
                  angle: -0.55,
                  child: Container(
                    width: 320,
                    height: 180,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: shimmerOpacity),
                          Colors.transparent,
                        ],
                      ),
                    ),
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

class _BgOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BgOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, Colors.transparent]),
        ),
      ),
    );
  }
}
