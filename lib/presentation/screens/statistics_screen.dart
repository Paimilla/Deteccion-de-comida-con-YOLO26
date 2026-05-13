import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';

import '../widgets/nutrifoto_ui.dart';

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
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const SkeletonBox(height: 50, borderRadius: 18),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(child: SkeletonBox(height: 120, borderRadius: 18)),
                            const SizedBox(width: 12),
                            const Expanded(child: SkeletonBox(height: 120, borderRadius: 18)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const SkeletonBox(height: 240, borderRadius: 22),
                        const SizedBox(height: 14),
                        const SkeletonBox(height: 180, borderRadius: 22),
                      ],
                    ),
                  )
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
    // Prepare data points for fl_chart
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.kcalTotal);
    }).toList();

    if (spots.isEmpty) {
      spots.add(const FlSpot(0, 0));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF172742),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calorías Diarias',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) return const SizedBox();
                        
                        final labels = monthMode
                            ? const ['S1', 'S2', 'S3', 'S4']
                            : const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
                        
                        final labelIndex = monthMode ? (index / 7).floor() : index;
                        if (labelIndex >= labels.length) return const SizedBox();

                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            labels[labelIndex],
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8A5CF6), Color(0xFFC084FC)],
                    ),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8A5CF6).withValues(alpha: 0.3),
                          const Color(0xFF8A5CF6).withValues(alpha: 0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => const Color(0xFF1F2937),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((s) {
                        return LineTooltipItem(
                          '${s.y.round()} kcal',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Removiendo pintores antiguos...

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.macro, this.compact = false});

  final _MacroBreakdown macro;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF172742),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución de Macros',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    value: macro.proteinGrams,
                    title: '${(macro.proteinPct * 100).round()}%',
                    color: const Color(0xFF71B7FF),
                    radius: 20,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: macro.carbsGrams,
                    title: '${(macro.carbsPct * 100).round()}%',
                    color: const Color(0xFFF9C533),
                    radius: 20,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: macro.fatGrams,
                    title: '${(macro.fatPct * 100).round()}%',
                    color: const Color(0xFF8F63FF),
                    radius: 20,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _MacroLegend(color: const Color(0xFF71B7FF), label: 'Prot', value: '${macro.proteinGrams.round()}g'),
              _MacroLegend(color: const Color(0xFFF9C533), label: 'Carb', value: '${macro.carbsGrams.round()}g'),
              _MacroLegend(color: const Color(0xFF8F63FF), label: 'Grasa', value: '${macro.fatGrams.round()}g'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  const _MacroLegend({required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
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
