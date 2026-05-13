import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_routes.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/nutrifoto_ui.dart';

class AddFoodHubScreen extends StatelessWidget {
  const AddFoodHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final selectedMealSlot = args is Map && args['mealSlot'] is MealSlot
        ? args['mealSlot'] as MealSlot
        : null;

    final actions = <_HubAction>[
      const _HubAction(
        title: 'Escanear con camara',
        subtitle: 'Detecta automaticamente tu comida con IA',
        icon: Icons.photo_camera,
        route: AppRoutes.scannerCamera,
        gradientIndex: 1,
      ),
      const _HubAction(
        title: 'Escanear codigo de barras',
        subtitle: 'Productos envasados por EAN/UPC',
        icon: Icons.qr_code_scanner,
        route: AppRoutes.scannerBarcode,
        gradientIndex: 2,
      ),
      const _HubAction(
        title: 'Buscar alimentos',
        subtitle: 'Consulta por nombre y agrega',
        icon: Icons.search,
        route: AppRoutes.search,
        gradientIndex: 3,
      ),
      const _HubAction(
        title: 'Recetas sugeridas',
        subtitle: 'Busca platos preparados e ideas',
        icon: Icons.menu_book_rounded,
        route: AppRoutes.recipes,
        gradientIndex: 5,
      ),
      const _HubAction(
        title: 'Registro por voz',
        subtitle: 'Habla o pega texto transcrito',
        icon: Icons.mic,
        route: AppRoutes.voice,
        gradientIndex: 4,
      ),
      const _HubAction(
        title: 'Agregar manualmente',
        subtitle: 'Foto de galeria o ingreso de macros',
        icon: Icons.edit_note,
        route: AppRoutes.manualEntry,
        gradientIndex: 0,
        photoSource: 'gallery',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar Comida')),
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.hoy),
      body: AnimatedScreenBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeroPanel(
                title: 'Registrar comida',
                subtitle:
                    'Elige una forma rapida y clara para registrar tu comida.',
                gradient: NutrifotoColors.scannerGradient,
                trailing: selectedMealSlot == null
                    ? null
                    : Text(
                        selectedMealSlot.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(height: 12),
              GradientCard(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                padding: const EdgeInsets.all(14),
                animate: false,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Sugerido: sube una foto y completa datos en 1 pantalla.',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        AppRoutes.manualEntry,
                        arguments: {
                          if (selectedMealSlot != null)
                            'mealSlot': selectedMealSlot,
                          'photoSource': 'gallery',
                        },
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Subir', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Metodos disponibles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...actions.map(
                (a) => _ActionCardAnimated(
                  action: a,
                  selectedMealSlot: selectedMealSlot,
                ),
              ),
              SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 80), // Espacio dinámico para bottom nav
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCardAnimated extends StatefulWidget {
  final _HubAction action;
  final MealSlot? selectedMealSlot;

  const _ActionCardAnimated({required this.action, this.selectedMealSlot});

  @override
  State<_ActionCardAnimated> createState() => _ActionCardAnimatedState();
}

class _ActionCardAnimatedState extends State<_ActionCardAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LinearGradient _getGradient(int index) {
    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    return gradients[index % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GradientCard(
          gradient: _getGradient(widget.action.gradientIndex),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          animate: false,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Colors.white.withValues(alpha: 0.2),
              onTap: () {
                HapticFeedback.lightImpact();
                final args = <String, dynamic>{
                  if (widget.selectedMealSlot != null)
                    'mealSlot': widget.selectedMealSlot,
                  if (widget.action.photoSource != null)
                    'photoSource': widget.action.photoSource,
                };

                Navigator.pushNamed(
                  context,
                  widget.action.route,
                  arguments: args.isEmpty ? null : args,
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.action.icon,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.action.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.action.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HubAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final int gradientIndex;
  final String? photoSource;

  const _HubAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.gradientIndex = 0,
    this.photoSource,
  });
}
