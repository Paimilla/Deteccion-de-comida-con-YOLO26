import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_routes.dart';
import 'nutrifoto_ui.dart';

class AppBottomNav extends StatelessWidget {
  final String currentRoute;

  const AppBottomNav({super.key, required this.currentRoute});

  static const _items = <_NavItem>[
    // Fitia Navigation Order
    _NavItem(
      route: AppRoutes.hoy,
      label: 'Hoy',
      icon: Icons.dashboard_rounded,
      semanticLabel: 'Resumen del día',
    ),
    _NavItem(
      route: AppRoutes.plan,
      label: 'Plan',
      icon: Icons.restaurant_menu_rounded,
      semanticLabel: 'Plan de comidas',
    ),
    _NavItem(
      route: AppRoutes.explorar,
      label: 'Explorar',
      icon: Icons.explore_rounded,
      semanticLabel: 'Explorar recetas',
    ),
    _NavItem(
      route: AppRoutes.progreso,
      label: 'Progreso',
      icon: Icons.trending_up_rounded,
      semanticLabel: 'Estadísticas y progreso',
    ),
    _NavItem(
      route: AppRoutes.perfil,
      label: 'Perfil',
      icon: Icons.person_rounded,
      semanticLabel: 'Ajustes y perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _items.indexWhere((i) => i.route == currentRoute);
    final selectedIndex = currentIndex < 0 ? 0 : currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A1128) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? NutrifotoColors.primary.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(bottom: bottomPad, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final isSelected = index == selectedIndex;

          return Expanded(
            child: Semantics(
              label: item.semanticLabel,
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (item.route == currentRoute) return;
                  HapticFeedback.selectionClick();
                  Navigator.pushReplacementNamed(context, item.route);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon with glow
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? NutrifotoColors.primary.withValues(alpha: 0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glow effect under selected icon
                            if (isSelected)
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: NutrifotoColors.primary
                                          .withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            Icon(
                              item.icon,
                              size: isSelected ? 26 : 22,
                              color: isSelected
                                  ? NutrifotoColors.primary
                                  : isDark
                                      ? Colors.white.withValues(alpha: 0.45)
                                      : Colors.black.withValues(alpha: 0.45),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Label
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontSize: isSelected ? 11 : 10,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? NutrifotoColors.primary
                              : isDark
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : Colors.black.withValues(alpha: 0.45),
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  final String route;
  final String label;
  final IconData icon;
  final String semanticLabel;

  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.semanticLabel,
  });
}
