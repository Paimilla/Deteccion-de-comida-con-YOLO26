import 'package:flutter/material.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';

enum _AchievementFilter { all, streak, meals }

enum _AchievementCategory { streak, meals }

class AchievementsScreen extends StatefulWidget {
  final AppServices services;

  const AchievementsScreen({super.key, required this.services});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgController;
  _AchievementFilter _filter = _AchievementFilter.all;
  bool _loading = true;
  String? _loadError;
  _AchievementMetrics _metrics = const _AchievementMetrics(
    streakDays: 0,
    bestStreak: 0,
    totalMeals: 0,
    daysOverTarget: 0,
    hydrationDays: 0,
    breakfastDays: 0,
    highProteinDays: 0,
    kcalGoalDays: 0,
  );
  List<_AchievementModel> _allAchievements = const [];
  int _unlockedCount = 0;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);
    _loadAchievements();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    try {
      final history = await widget.services.historyUseCases.lastNDays(90);
      final metrics = _AchievementMetrics.from(history);
      final achievements = _buildAchievements(metrics);
      if (!mounted) return;
      setState(() {
        _metrics = metrics;
        _allAchievements = achievements;
        _unlockedCount = achievements.where((a) => a.unlocked).length;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudieron cargar los logros.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;
    final gridColumns = screenWidth >= 1000
        ? 4
        : screenWidth >= 700
        ? 3
        : screenWidth >= 380
        ? 2
        : 1;
    final gridAspect = gridColumns == 1
        ? 1.55
        : gridColumns == 2
        ? 0.83
        : 0.9;
    final filtered = _allAchievements
        .where(
          (a) => switch (_filter) {
            _AchievementFilter.all => true,
            _AchievementFilter.streak =>
              a.category == _AchievementCategory.streak,
            _AchievementFilter.meals =>
              a.category == _AchievementCategory.meals,
          },
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logros y Rachas'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8A5CF6), Color(0xFF6F3CE8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: const [],
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
                    child: _AchievementsBackdrop(animation: _bgController),
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
                      _StreakHero(
                        metrics: _metrics,
                        unlockedCount: _unlockedCount,
                        compact: isCompact,
                      ),
                      const SizedBox(height: 12),
                      _FilterRow(
                        selected: _filter,
                        onChanged: (value) => setState(() => _filter = value),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        itemCount: filtered.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridColumns,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: gridAspect,
                        ),
                        itemBuilder: (context, index) =>
                            _AchievementCard(achievement: filtered[index]),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.plan),
    );
  }

  List<_AchievementModel> _buildAchievements(_AchievementMetrics metrics) {
    return [
      _AchievementModel(
        emoji: '🔥',
        title: 'Principiante Constante',
        subtitle: 'Registra comidas 3 dias seguidos',
        current: metrics.streakDays.clamp(0, 3).toInt(),
        goal: 3,
        category: _AchievementCategory.streak,
      ),
      _AchievementModel(
        emoji: '⭐',
        title: 'Una Semana Fuerte',
        subtitle: 'Registra comidas 7 dias seguidos',
        current: metrics.streakDays.clamp(0, 7).toInt(),
        goal: 7,
        category: _AchievementCategory.streak,
      ),
      _AchievementModel(
        emoji: '💪',
        title: 'Dos Semanas de Poder',
        subtitle: 'Registra comidas 14 dias seguidos',
        current: metrics.streakDays.clamp(0, 14).toInt(),
        goal: 14,
        category: _AchievementCategory.streak,
      ),
      _AchievementModel(
        emoji: '👑',
        title: 'Mes Legendario',
        subtitle: 'Registra comidas 30 dias seguidos',
        current: metrics.streakDays.clamp(0, 30).toInt(),
        goal: 30,
        category: _AchievementCategory.streak,
      ),
      _AchievementModel(
        emoji: '🍽️',
        title: 'Comedor Activo',
        subtitle: 'Registra 60 comidas',
        current: metrics.totalMeals.clamp(0, 60).toInt(),
        goal: 60,
        category: _AchievementCategory.meals,
      ),
      _AchievementModel(
        emoji: '🎯',
        title: 'Objetivo Nutri',
        subtitle: 'Logra 15 dias sobre 1800 kcal',
        current: metrics.daysOverTarget.clamp(0, 15).toInt(),
        goal: 15,
        category: _AchievementCategory.meals,
      ),
      _AchievementModel(
        emoji: '⚡',
        title: 'Tercera Semana',
        subtitle: 'Registra comidas 21 dias seguidos',
        current: metrics.streakDays.clamp(0, 21).toInt(),
        goal: 21,
        category: _AchievementCategory.streak,
      ),
      _AchievementModel(
        emoji: '🛡️',
        title: 'Racha Imparable',
        subtitle: 'Registra comidas 45 dias seguidos',
        current: metrics.streakDays.clamp(0, 45).toInt(),
        goal: 45,
        category: _AchievementCategory.streak,
      ),
      _AchievementModel(
        emoji: '🏅',
        title: 'Comidas 100',
        subtitle: 'Registra 100 comidas en total',
        current: metrics.totalMeals.clamp(0, 100).toInt(),
        goal: 100,
        category: _AchievementCategory.meals,
      ),
      _AchievementModel(
        emoji: '🥤',
        title: 'Hidratacion Top',
        subtitle: 'Llega a 2000ml en 10 dias',
        current: metrics.hydrationDays.clamp(0, 10).toInt(),
        goal: 10,
        category: _AchievementCategory.meals,
      ),
      _AchievementModel(
        emoji: '🍳',
        title: 'Desayuno Conquista',
        subtitle: 'Registra desayuno en 20 dias',
        current: metrics.breakfastDays.clamp(0, 20).toInt(),
        goal: 20,
        category: _AchievementCategory.meals,
      ),
      _AchievementModel(
        emoji: '🥩',
        title: 'Proteina Firme',
        subtitle: 'Supera 100g de proteina en 12 dias',
        current: metrics.highProteinDays.clamp(0, 12).toInt(),
        goal: 12,
        category: _AchievementCategory.meals,
      ),
      _AchievementModel(
        emoji: '🎚️',
        title: 'Balance Diario',
        subtitle: 'Queda cerca del objetivo en 15 dias',
        current: metrics.kcalGoalDays.clamp(0, 15).toInt(),
        goal: 15,
        category: _AchievementCategory.meals,
      ),
    ];
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({
    required this.metrics,
    required this.unlockedCount,
    this.compact = false,
  });

  final _AchievementMetrics metrics;
  final int unlockedCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8D63FF), Color(0xFF7043ED)],
        ),
      ),
      child: Column(
        children: [
          Text('🔥', style: TextStyle(fontSize: compact ? 34 : 43)),
          const SizedBox(height: 4),
          Text(
            '${metrics.streakDays}',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 34 : 42,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            metrics.streakDays == 1 ? 'dia de racha' : 'dias de racha',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: compact ? 16 : 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: '⭐',
                  value: '${metrics.bestStreak}',
                  label: 'Mejor Racha',
                  compact: compact,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  icon: '🍽️',
                  value: '${metrics.totalMeals}',
                  label: 'Comidas',
                  compact: compact,
                ),
              ),
              Expanded(
                child: _HeroStat(
                  icon: '🎯',
                  value: '$unlockedCount',
                  label: 'Metas',
                  compact: compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
    this.compact = false,
  });

  final String icon;
  final String value;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: TextStyle(fontSize: compact ? 14 : 17)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 17 : 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.selected, required this.onChanged});

  final _AchievementFilter selected;
  final ValueChanged<_AchievementFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipButton(
            label: 'Todos',
            selected: selected == _AchievementFilter.all,
            onTap: () => onChanged(_AchievementFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: '🔥 Rachas',
            selected: selected == _AchievementFilter.streak,
            onTap: () => onChanged(_AchievementFilter.streak),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: '🍽️ Comidas',
            selected: selected == _AchievementFilter.meals,
            onTap: () => onChanged(_AchievementFilter.meals),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFF8A5CF6) : const Color(0xFFE8E8E8);
    final fg = selected ? Colors.white : const Color(0xFF1F1F1F);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final _AchievementModel achievement;

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFF13243F) : const Color(0xFF2A2F3A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked
              ? const Color(0xFF8A5CF6).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.08),
          width: unlocked ? 2 : 1,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: const Color(0xFF8A5CF6).withValues(alpha: 0.19),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Text(
            achievement.emoji,
            style: TextStyle(
              fontSize: unlocked ? 34 : 32,
              color: unlocked ? null : Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: unlocked ? 1 : 0.75),
              fontWeight: FontWeight.w900,
              fontSize: 16,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: achievement.progress,
              color: const Color(0xFF8A5CF6),
              backgroundColor: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${achievement.current}/${achievement.goal}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: unlocked
                  ? const Color(0xFF8A5CF6).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              unlocked ? 'Desbloqueado' : 'En progreso',
              style: TextStyle(
                color: unlocked
                    ? const Color(0xFFDCCEFF)
                    : Colors.white.withValues(alpha: 0.58),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementModel {
  const _AchievementModel({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.current,
    required this.goal,
    required this.category,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final int current;
  final int goal;
  final _AchievementCategory category;

  bool get unlocked => current >= goal;
  double get progress => (current / goal).clamp(0, 1).toDouble();
}

class _AchievementMetrics {
  const _AchievementMetrics({
    required this.streakDays,
    required this.bestStreak,
    required this.totalMeals,
    required this.daysOverTarget,
    required this.hydrationDays,
    required this.breakfastDays,
    required this.highProteinDays,
    required this.kcalGoalDays,
  });

  final int streakDays;
  final int bestStreak;
  final int totalMeals;
  final int daysOverTarget;
  final int hydrationDays;
  final int breakfastDays;
  final int highProteinDays;
  final int kcalGoalDays;

  factory _AchievementMetrics.from(List<DailySummary> days) {
    if (days.isEmpty) {
      return const _AchievementMetrics(
        streakDays: 0,
        bestStreak: 0,
        totalMeals: 0,
        daysOverTarget: 0,
        hydrationDays: 0,
        breakfastDays: 0,
        highProteinDays: 0,
        kcalGoalDays: 0,
      );
    }

    final sorted = [...days]..sort((a, b) => a.day.compareTo(b.day));

    var running = 0;
    var best = 0;
    for (final day in sorted) {
      if (day.entries.isNotEmpty) {
        running += 1;
        if (running > best) best = running;
      } else {
        running = 0;
      }
    }

    var current = 0;
    for (var i = sorted.length - 1; i >= 0; i--) {
      if (sorted[i].entries.isEmpty) {
        break;
      }
      current += 1;
    }

    final mealCount = sorted.fold<int>(
      0,
      (sum, day) => sum + day.entries.length,
    );
    final daysOverTarget = sorted.where((day) => day.kcalTotal >= 1800).length;
    final hydrationDays = sorted.where((day) => day.hydrationMl >= 2000).length;
    final breakfastDays = sorted
        .where(
          (day) =>
              day.entries.any((entry) => entry.mealSlot == MealSlot.desayuno),
        )
        .length;
    final highProteinDays = sorted
        .where((day) => day.proteinTotal >= 100)
        .length;
    final kcalGoalDays = sorted
        .where((day) => (day.kcalTotal - day.goals.kcal).abs() <= 200)
        .length;

    return _AchievementMetrics(
      streakDays: current,
      bestStreak: best,
      totalMeals: mealCount,
      daysOverTarget: daysOverTarget,
      hydrationDays: hydrationDays,
      breakfastDays: breakfastDays,
      highProteinDays: highProteinDays,
      kcalGoalDays: kcalGoalDays,
    );
  }
}

class _AchievementsBackdrop extends StatelessWidget {
  const _AchievementsBackdrop({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _AchievementsBackdropPainter(t: animation.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _AchievementsBackdropPainter extends CustomPainter {
  _AchievementsBackdropPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final orb1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF8A5CF6).withValues(alpha: 0.22),
              const Color(0xFF8A5CF6).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * (0.25 + 0.18 * t), size.height * 0.2),
              radius: size.width * 0.4,
            ),
          );

    final orb2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF4DA2FF).withValues(alpha: 0.16),
              const Color(0xFF4DA2FF).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * (0.82 - 0.2 * t), size.height * 0.66),
              radius: size.width * 0.46,
            ),
          );

    final orb3 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF9D79FF).withValues(alpha: 0.12),
              const Color(0xFF9D79FF).withValues(alpha: 0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * 0.58,
                size.height * (0.92 - 0.12 * t),
              ),
              radius: size.width * 0.34,
            ),
          );

    canvas.drawRect(Offset.zero & size, orb1);
    canvas.drawRect(Offset.zero & size, orb2);
    canvas.drawRect(Offset.zero & size, orb3);
  }

  @override
  bool shouldRepaint(covariant _AchievementsBackdropPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}
