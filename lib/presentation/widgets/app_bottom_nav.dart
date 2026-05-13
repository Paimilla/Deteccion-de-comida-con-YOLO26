import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_routes.dart';
import 'nutrifoto_ui.dart';

class AppBottomNav extends StatelessWidget {
  final String currentRoute;

  const AppBottomNav({super.key, required this.currentRoute});

  static const _items = <_NavItem>[
    _NavItem(
      route: AppRoutes.hoy,
      label: 'Comida',
      icon: Icons.restaurant_rounded,
      semanticLabel: 'Mi comida y diario',
    ),
    _NavItem(
      route: AppRoutes.progreso,
      label: 'Progreso',
      icon: Icons.trending_up_rounded,
      semanticLabel: 'Estadísticas y progreso',
    ),
    _NavItem(
      route: AppRoutes.assistant,
      label: 'Asistente IA',
      icon: Icons.auto_awesome_rounded,
      semanticLabel: 'Asistente inteligente',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _items.indexWhere((i) => i.route == currentRoute);
    final selectedIndex = currentIndex < 0 ? 0 : currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 70 + bottomPad,
          padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPad + 8),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0D1225) : Colors.white).withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final isSelected = index == selectedIndex;

              return Expanded(
                child: InkWell(
                  onTap: () {
                    if (item.route == currentRoute) return;
                    HapticFeedback.selectionClick();
                    Navigator.pushReplacementNamed(context, item.route);
                  },
                  highlightColor: Colors.transparent,
                  splashColor: NutrifotoColors.primary.withValues(alpha: 0.1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 24,
                        color: isSelected
                            ? NutrifotoColors.primary
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          color: isSelected
                              ? NutrifotoColors.primary
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
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
