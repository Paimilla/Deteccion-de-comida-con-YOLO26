import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/nutrifoto_ui.dart';

class HistoryScreen extends StatefulWidget {
  final AppServices services;

  const HistoryScreen({super.key, required this.services});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  late DateTime _selectedDay;
  DailySummary? _selectedSummary;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _selectedDay = _onlyDate(DateTime.now());
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
    _loadSelectedDay();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  DateTime _onlyDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Future<void> _loadSelectedDay() async {
    final selected = await widget.services.trackingUseCases.getDailySummary(
      _selectedDay,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedSummary = selected;
      _loading = false;
    });
  }

  Future<void> _onDaySelected(DateTime day) async {
    setState(() {
      _selectedDay = _onlyDate(day);
      _loading = true;
    });
    await _loadSelectedDay();
  }

  String _fmtDate(DateTime day) {
    final d = day.day.toString().padLeft(2, '0');
    final m = day.month.toString().padLeft(2, '0');
    return '$d/$m/${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedSummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          IconButton(
            tooltip: 'Estadisticas',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.statistics),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
          IconButton(
            tooltip: 'Logros',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.achievements),
            icon: const Icon(Icons.emoji_events_outlined),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.plan),
      body: _loading
          ? const LoadingBlock(message: 'Cargando historial...')
          : AnimatedScreenBody(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _HistoryBackdrop(animation: _ambientController),
                    ),
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const HeroPanel(
                        title: 'Historial',
                        subtitle: 'Selecciona un dia para revisar tu resumen',
                        gradient: NutrifotoColors.searchGradient,
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Calendario',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            CalendarDatePicker(
                              initialDate: _selectedDay,
                              firstDate: _onlyDate(
                                DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                              ),
                              lastDate: _onlyDate(DateTime.now()),
                              onDateChanged: _onDaySelected,
                              currentDate: _onlyDate(DateTime.now()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selected != null)
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resumen del ${_fmtDate(selected.day)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Calorias',
                                      value:
                                          '${selected.kcalTotal.toStringAsFixed(0)} kcal',
                                      icon: Icons.local_fire_department,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Registros',
                                      value: '${selected.entries.length}',
                                      icon: Icons.restaurant_menu,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StatTile(
                                      label: 'Agua',
                                      value: '${selected.hydrationMl} ml',
                                      icon: Icons.water_drop,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'P/C/G: ${selected.proteinTotal.toStringAsFixed(1)} / ${selected.carbsTotal.toStringAsFixed(1)} / ${selected.fatTotal.toStringAsFixed(1)} g',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (selected.entries.isEmpty)
                                const Text(
                                  'No hay comidas registradas este dia.',
                                )
                              else
                                ...selected.entries.take(8).map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.fiber_manual_record,
                                          size: 10,
                                          color: NutrifotoColors.accentBlue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${entry.mealSlot.label}: ${entry.food.nameEs}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${entry.food.nutrition.kcal.toStringAsFixed(0)} kcal',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _HistoryBackdrop extends StatelessWidget {
  final Animation<double> animation;

  const _HistoryBackdrop({required this.animation});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _HistoryBackdropPainter(
            progress: animation.value,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

class _HistoryBackdropPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _HistoryBackdropPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = (isDark ? const Color(0x3399B2FF) : const Color(0x227C93E6));

    for (var i = 0; i < 4; i++) {
      final path = Path();
      final baseY = size.height * (0.18 + i * 0.16);
      path.moveTo(-20, baseY);
      for (double x = -20; x <= size.width + 20; x += 14) {
        final y = baseY + math.sin((x / 80) + (t * 6) + i) * (8 + i * 2);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? NutrifotoColors.surfaceSoft
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: NutrifotoColors.accentBlue),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? NutrifotoColors.textMuted : Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
