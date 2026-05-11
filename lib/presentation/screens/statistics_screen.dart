import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';

class StatisticsScreen extends StatefulWidget {
  final AppServices services;

  const StatisticsScreen({super.key, required this.services});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgController;
  bool _monthMode = false;
  bool _loading = true;
  String? _loadError;
  List<DailySummary> _monthData = const [];

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _loadStats();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final data = await widget.services.historyUseCases.lastNDays(30);
      if (!mounted) return;
      setState(() {
        _monthData = data;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudieron cargar las estadisticas.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;

    final data = _monthMode
        ? _monthData
        : (_monthData.length > 7 ? _monthData.sublist(0, 7) : _monthData);

    final avgKcal = _averageCalories(data);
    final bestDay = _bestDayCalories(data);
    final macro = _macroBreakdown(data);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadisticas'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8A5CF6), Color(0xFF6F3CE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: AnimatedScreenBody(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF09142A), Color(0xFF0B1730), Color(0xFF0A162B)],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: _StatisticsBackdrop(animation: _bgController),
                  ),
                ),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_loadError != null)
                  Center(
                    child: Text(
                      _loadError!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ListView(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 12 : 16,
                      14,
                      isCompact ? 12 : 16,
                      110,
                    ),
                    children: [
                      _ModeSwitch(
                        monthMode: _monthMode,
                        onChanged: (value) =>
                            setState(() => _monthMode = value),
                      ),
                      const SizedBox(height: 14),
                      if (isCompact)
                        Column(
                          children: [
                            _MiniStatCard(
                              emoji: '📊',
                              label: 'Promedio Diario',
                              value: '${avgKcal.round()} kcal',
                              compact: true,
                            ),
                            const SizedBox(height: 12),
                            _MiniStatCard(
                              emoji: '🎯',
                              label: 'Mejor Dia',
                              value: bestDay > 0
                                  ? bestDay.round().toString()
                                  : '--',
                              compact: true,
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: _MiniStatCard(
                                emoji: '📊',
                                label: 'Promedio Diario',
                                value: '${avgKcal.round()} kcal',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _MiniStatCard(
                                emoji: '🎯',
                                label: 'Mejor Dia',
                                value: bestDay > 0
                                    ? bestDay.round().toString()
                                    : '--',
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),
                      _ChartCard(
                        data: data,
                        monthMode: _monthMode,
                        compact: isCompact,
                      ),
                      const SizedBox(height: 14),
                      _MacroCard(macro: macro, compact: isCompact),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.progreso),
    );
  }

  double _averageCalories(List<DailySummary> list) {
    if (list.isEmpty) return 0;
    final total = list.fold<double>(0, (sum, day) => sum + day.kcalTotal);
    return total / list.length;
  }

  double _bestDayCalories(List<DailySummary> list) {
    if (list.isEmpty) return 0;
    return list
        .map((day) => day.kcalTotal)
        .fold<double>(0, (best, value) => math.max(best, value));
  }

  _MacroBreakdown _macroBreakdown(List<DailySummary> list) {
    final protein = list.fold<double>(0, (sum, day) => sum + day.proteinTotal);
    final carbs = list.fold<double>(0, (sum, day) => sum + day.carbsTotal);
    final fat = list.fold<double>(0, (sum, day) => sum + day.fatTotal);
    final total = protein + carbs + fat;

    if (total <= 0) {
      return const _MacroBreakdown(proteinPct: 0, carbsPct: 0, fatPct: 0);
    }

    return _MacroBreakdown(
      proteinPct: protein / total,
      carbsPct: carbs / total,
      fatPct: fat / total,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.monthMode, required this.onChanged});

  final bool monthMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111F3A),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              title: 'Semana',
              selected: !monthMode,
              onTap: () => onChanged(false),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ModeButton(
              title: 'Mes',
              selected: monthMode,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF8A5CF6) : const Color(0xFFE8E8E8);
    final fg = selected ? Colors.white : const Color(0xFF262626);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({
    required this.emoji,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String emoji;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF172742),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: compact ? 24 : 28)),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 24 : 27,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.data,
    required this.monthMode,
    this.compact = false,
  });

  final List<DailySummary> data;
  final bool monthMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF172742),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calorias por Dia',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 22 : 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: compact ? 180 : 210,
            child: CustomPaint(
              painter: _KcalLineChartPainter(
                values: data.map((d) => d.kcalTotal).toList(),
                monthMode: monthMode,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _KcalLineChartPainter extends CustomPainter {
  _KcalLineChartPainter({required this.values, required this.monthMode});

  final List<double> values;
  final bool monthMode;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) {
      return;
    }

    final maxValue = values.reduce(math.max);
    final top = maxValue <= 0 ? 100 : maxValue * 1.15;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final dx = values.length == 1
          ? 0.0
          : size.width * (i / (values.length - 1));
      final dy = size.height - (values[i] / top) * size.height;
      points.add(Offset(dx, dy.clamp(0, size.height)));
    }

    final areaPath = Path()..moveTo(points.first.dx, size.height);
    for (final point in points) {
      areaPath.lineTo(point.dx, point.dy);
    }
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.close();

    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x558C63FF), Color(0x008C63FF)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(areaPath, fill);

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final midX = (prev.dx + current.dx) / 2;
      linePath.cubicTo(midX, prev.dy, midX, current.dy, current.dx, current.dy);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF8D63FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(linePath, linePaint);

    final glowPaint = Paint()
      ..color = const Color(0xFF8D63FF).withValues(alpha: 0.33)
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 8, glowPaint);
      canvas.drawCircle(point, 4, dotPaint);
    }

    final labels = monthMode
        ? const ['S1', 'S2', 'S3', 'S4']
        : const ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];

    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.52),
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    if (monthMode) {
      for (var i = 0; i < labels.length; i++) {
        final x = size.width * (i / (labels.length - 1));
        _drawLabel(canvas, labels[i], textStyle, x, size.height - 2);
      }
    } else {
      for (var i = 0; i < labels.length && i < points.length; i++) {
        _drawLabel(canvas, labels[i], textStyle, points[i].dx, size.height - 2);
      }
    }
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    TextStyle style,
    double x,
    double y,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    painter.paint(
      canvas,
      Offset(
        (x - painter.width / 2).clamp(0, double.infinity),
        y - painter.height,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _KcalLineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.monthMode != monthMode;
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.macro, this.compact = false});

  final _MacroBreakdown macro;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF172742),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribucion de Macros',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 22 : 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = compact || constraints.maxWidth < 370;
              final donutSize = narrow ? 120.0 : 144.0;
              final legends = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MacroLegend(
                    color: const Color(0xFF71B7FF),
                    label: 'Proteina',
                    value:
                        '${(macro.proteinPct * 100).round()}%  ${macro.proteinGrams.toStringAsFixed(1)} g',
                  ),
                  const SizedBox(height: 10),
                  _MacroLegend(
                    color: const Color(0xFFF9C533),
                    label: 'Carbs',
                    value:
                        '${(macro.carbsPct * 100).round()}%  ${macro.carbsGrams.toStringAsFixed(1)} g',
                  ),
                  const SizedBox(height: 10),
                  _MacroLegend(
                    color: const Color(0xFF8F63FF),
                    label: 'Grasa',
                    value:
                        '${(macro.fatPct * 100).round()}%  ${macro.fatGrams.toStringAsFixed(1)} g',
                  ),
                ],
              );

              if (narrow) {
                return Column(
                  children: [
                    SizedBox(
                      width: donutSize,
                      height: donutSize,
                      child: CustomPaint(
                        painter: _MacroDonutPainter(macro: macro),
                      ),
                    ),
                    const SizedBox(height: 14),
                    legends,
                  ],
                );
              }

              return Row(
                children: [
                  SizedBox(
                    width: donutSize,
                    height: donutSize,
                    child: CustomPaint(
                      painter: _MacroDonutPainter(macro: macro),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: legends),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  const _MacroLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 11,
          height: 11,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MacroDonutPainter extends CustomPainter {
  _MacroDonutPainter({required this.macro});

  final _MacroBreakdown macro;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 2;
    const stroke = 24.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final rawValues = [
      macro.proteinPct,
      macro.carbsPct,
      macro.fatPct,
    ].map((v) => v.isFinite ? v.clamp(0.0, 1.0) : 0.0).toList();
    final total = rawValues.fold<double>(0, (sum, v) => sum + v);
    const colors = [Color(0xFF71B7FF), Color(0xFFF9C533), Color(0xFF8F63FF)];

    final trackPaint = Paint()
      ..color = const Color(0xFF2A3A57)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    if (total <= 0.0001) {
      return;
    }

    const gapAngle = 0.05;
    const start = -math.pi / 2;
    var current = start;

    final normalized = rawValues.map((v) => v / total).toList();
    final nonZeroCount = normalized.where((v) => v > 0).length;
    final totalGap = gapAngle * nonZeroCount;
    final drawable = (2 * math.pi - totalGap).clamp(0.0, 2 * math.pi);

    for (var i = 0; i < normalized.length; i++) {
      final ratio = normalized[i];
      if (ratio <= 0) continue;

      final sweep = drawable * ratio;
      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, current, sweep, false, paint);
      current += sweep + gapAngle;
    }

    final hole = Paint()..color = const Color(0xFF121F39);
    canvas.drawCircle(center, radius - (stroke / 2 + 4), hole);
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) {
    return oldDelegate.macro != macro;
  }
}

class _MacroBreakdown {
  const _MacroBreakdown({
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
  });

  final double proteinPct;
  final double carbsPct;
  final double fatPct;

  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _MacroBreakdown &&
        other.proteinPct == proteinPct &&
        other.carbsPct == carbsPct &&
        other.fatPct == fatPct &&
        other.proteinGrams == proteinGrams &&
        other.carbsGrams == carbsGrams &&
        other.fatGrams == fatGrams;
  }

  @override
  int get hashCode => Object.hash(
    proteinPct,
    carbsPct,
    fatPct,
    proteinGrams,
    carbsGrams,
    fatGrams,
  );
}

class _StatisticsBackdrop extends StatelessWidget {
  const _StatisticsBackdrop({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _StatisticsBackdropPainter(t: animation.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _StatisticsBackdropPainter extends CustomPainter {
  _StatisticsBackdropPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF8D63FF).withValues(alpha: 0.2),
              const Color(0xFF8D63FF).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * (0.18 + 0.2 * t), size.height * 0.24),
              radius: size.width * 0.44,
            ),
          );

    final p2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF4DA2FF).withValues(alpha: 0.15),
              const Color(0xFF4DA2FF).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * (0.84 - 0.18 * t),
                size.height * 0.58,
              ),
              radius: size.width * 0.42,
            ),
          );

    final p3 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF9A7BFF).withValues(alpha: 0.13),
              const Color(0xFF9A7BFF).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.52, size.height * (0.92 - 0.1 * t)),
              radius: size.width * 0.32,
            ),
          );

    canvas.drawRect(Offset.zero & size, p1);
    canvas.drawRect(Offset.zero & size, p2);
    canvas.drawRect(Offset.zero & size, p3);
  }

  @override
  bool shouldRepaint(covariant _StatisticsBackdropPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}
