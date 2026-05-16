import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/swipeable_food_card.dart';
import '../widgets/smart_substitution_sheet.dart';
import '../widgets/edit_food_entry_sheet.dart';
import '../widgets/nutrifoto_ui.dart';
import '../widgets/ambient_background.dart';
import '../../application/meal_clipboard.dart';

class HomeScreen extends StatefulWidget {
  final AppServices services;

  const HomeScreen({super.key, required this.services});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  double _kcal = 0;
  double _kcalGoal = 2200;
  double _proteinTotal = 0;
  double _carbsTotal = 0;
  double _fatTotal = 0;
  bool _isLoading = false;
  DateTime _selectedDate = _dateOnly(DateTime.now());
  late DateTime _weekStart;
  late final AnimationController _ambientController;
  late final StreamSubscription<void> _repoSubscription;

  Map<MealSlot, double> _mealKcal = {
    MealSlot.desayuno: 0,
    MealSlot.almuerzo: 0,
    MealSlot.cena: 0,
    MealSlot.once: 0,
    MealSlot.snack: 0,
  };
  Map<MealSlot, List<DiaryEntry>> _mealEntries = {
    MealSlot.desayuno: const [],
    MealSlot.almuerzo: const [],
    MealSlot.cena: const [],
    MealSlot.once: const [],
    MealSlot.snack: const [],
  };

  // Streak tracking (simulated for now - connect to real data later)
  int _currentStreak = 0;
  int _totalDays = 0;


  IconData _iconForMeal(MealSlot slot) {
    switch (slot) {
      case MealSlot.desayuno:
        return Icons.breakfast_dining_rounded;
      case MealSlot.almuerzo:
        return Icons.flatware_rounded;
      case MealSlot.cena:
        return Icons.dinner_dining_rounded;
      case MealSlot.once:
        return Icons.emoji_food_beverage_rounded;
      case MealSlot.snack:
        return Icons.cookie_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 11),
    )..repeat(reverse: true);
    _weekStart = _startOfWeek(_selectedDate);
    _loadStreakData();
    _refreshSummary();

    // Escuchar actualizaciones del repositorio para refrescar instantáneamente
    _repoSubscription = widget.services.trackingUseCases.repository.onRepositoryUpdated.listen((_) {
      if (mounted) _refreshSummary(showLoading: false);
    });
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _repoSubscription.cancel();
    super.dispose();
  }

  /// Carga datos de streak persistidos
  Future<void> _loadStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentStreak = prefs.getInt('current_streak') ?? 0;
        _totalDays = prefs.getInt('total_days') ?? 0;
      });
    } catch (e) {
      // Fallar silenciosamente si SharedPreferences no funciona
    }
  }

  /// Guarda datos de streak persistidos
  Future<void> _saveStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_streak', _currentStreak);
      await prefs.setInt('total_days', _totalDays);
    } catch (e) {
      // Fallar silenciosamente si SharedPreferences no funciona
    }
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _startOfWeek(DateTime date) {
    final normalized = _dateOnly(date);
    return normalized.subtract(
      Duration(days: normalized.weekday - DateTime.monday),
    );
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  Future<void> _refreshSummary({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    final summary = await widget.services.trackingUseCases.getDailySummary(
      _selectedDate,
    );
    if (!mounted) {
      return;
    }

    final mealMap = {
      MealSlot.desayuno: 0.0,
      MealSlot.almuerzo: 0.0,
      MealSlot.cena: 0.0,
      MealSlot.once: 0.0,
      MealSlot.snack: 0.0,
    };
    final entryMap = {
      MealSlot.desayuno: <DiaryEntry>[],
      MealSlot.almuerzo: <DiaryEntry>[],
      MealSlot.cena: <DiaryEntry>[],
      MealSlot.once: <DiaryEntry>[],
      MealSlot.snack: <DiaryEntry>[],
    };
    for (final entry in summary.entries) {
      mealMap[entry.mealSlot] =
          (mealMap[entry.mealSlot] ?? 0) + entry.food.nutrition.kcal;
      entryMap[entry.mealSlot]?.add(entry);
    }

    for (final slot in MealSlot.values) {
      entryMap[slot]?.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    setState(() {
      _kcal = summary.kcalTotal;
      _kcalGoal = summary.goals.kcal;
      _proteinTotal = summary.proteinTotal;
      _carbsTotal = summary.carbsTotal;
      _fatTotal = summary.fatTotal;
      _mealKcal = mealMap;
      _mealEntries = entryMap;
      _isLoading = false;
    });

    // Update streak based on history
    _updateRealStreak();
  }

  Future<void> _updateRealStreak() async {
    final summaries = await widget.services.historyUseCases.lastNDays(30);
    final completedDays = summaries
        .where((s) => s.entries.isNotEmpty)
        .map((s) => s.day)
        .toList();

    if (mounted) {
      setState(() {
        _currentStreak = widget.services.insightsUseCases.streakDays(completedDays);
        _totalDays = summaries.where((s) => s.entries.isNotEmpty).length;
      });
      await _saveStreakData();
    }
  }

  Future<void> _changeDay(DateTime day) async {
    final next = _dateOnly(day);
    if (next == _selectedDate) {
      return;
    }
    setState(() {
      _selectedDate = next;
      _weekStart = _startOfWeek(next);
    });
    await _refreshSummary();
  }

  Future<void> _shiftWeek(int deltaWeeks) async {
    final nextWeekStart = _weekStart.add(Duration(days: 7 * deltaWeeks));
    final preferredWeekday = _selectedDate.weekday - DateTime.monday;
    final nextSelected = nextWeekStart.add(
      Duration(days: preferredWeekday.clamp(0, 6)),
    );
    setState(() {
      _weekStart = nextWeekStart;
      _selectedDate = nextSelected;
    });
    await _refreshSummary();
  }

  /// Camera-First: Tap on meal → open scanner camera directly
  Future<void> _openCameraFirst(MealSlot slot) async {
    HapticFeedback.selectionClick();
    await Navigator.pushNamed(
      context,
      AppRoutes.scannerCamera,
      arguments: {
        'mealSlot': slot,
        'date': _selectedDate,
      },
    );
    if (mounted) {
      await _refreshSummary();
    }
  }

  Future<void> _deleteEntry(String entryId) async {
    HapticFeedback.mediumImpact();
    await widget.services.trackingUseCases.removeFoodEntry(entryId);
    if (!mounted) return;
    await _refreshSummary();
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Alimento eliminado')),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _duplicateEntry(DiaryEntry entry) async {
    HapticFeedback.lightImpact();
    await widget.services.trackingUseCases.duplicateFoodEntry(entry);
    if (!mounted) return;
    await _refreshSummary();
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('${entry.food.nameEs} duplicado')),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openSubstitution(DiaryEntry entry) async {
    final result = await SmartSubstitutionSheet.show(
      context: context,
      originalFood: entry.food,
      mealSlot: entry.mealSlot,
      services: widget.services,
      entryId: entry.id,
    );
    if (result != null && mounted) {
      await _refreshSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Cambiado a ${result.nameEs}')),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _moveEntry(DiaryEntry entry, MealSlot newSlot) async {
    HapticFeedback.lightImpact();
    final original = await widget.services.trackingUseCases.moveFoodEntry(
      entryId: entry.id,
      targetSlot: newSlot,
    );
    if (original != null && mounted) {
      await _refreshSummary();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${entry.food.nameEs} movido a ${newSlot.label}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              await widget.services.trackingUseCases.undoDelete(original);
              if (mounted) await _refreshSummary();
            },
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showEditSheet(DiaryEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditFoodEntrySheet(
        entry: entry,
        onSave: (updated) async {
          await widget.services.trackingUseCases.updateFoodEntry(updated);
          if (mounted) await _refreshSummary();
        },
      ),
    );
  }

  void _copyEntry(DiaryEntry entry) {
    MealClipboard.copy(entry);
    setState(() {}); // Rebuild to show Paste buttons
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alimento copiado al portapapeles'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _pasteEntry(MealSlot slot) async {
    final entry = MealClipboard.copiedEntry;
    if (entry == null) return;

    await widget.services.trackingUseCases.addFoodEntry(
      mealSlot: slot,
      food: entry.food,
      timestamp: _selectedDate,
    );
    if (mounted) await _refreshSummary();
  }

  void _showEntryOptions(DiaryEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.swap_horiz_rounded, color: NutrifotoColors.primary),
              title: const Text('Sustitución Inteligente', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _openSubstitution(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.blue),
              title: const Text('Copiar', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _copyEntry(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.amber),
              title: const Text('Editar cantidad', style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(ctx);
                _showEditSheet(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Borrar', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteEntry(entry.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Buenos dias'
        : (hour < 20 ? 'Buenas tardes' : 'Buenas noches');
    final kcalPct = (_kcalGoal <= 0 ? 0 : _kcal / _kcalGoal)
        .clamp(0, 1)
        .toDouble();
    
    // Macros reales del resumen diario
    final proteinG = _proteinTotal;
    final fatG = _fatTotal;
    final carbsG = _carbsTotal;

    // Objetivos: mismo cálculo que para actuals pero basado en kcal goal
    final proteinTarget = (_kcalGoal * 0.32 / 4);
    final carbsTarget = (_kcalGoal * 0.42 / 4);
    final fatTarget = (_kcalGoal * 0.26 / 9);
    final weekDays = _weekDays;
    final dateKey =
        '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    const monthNames = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final selectedDateTitle =
        '${_selectedDate.day} ${monthNames[_selectedDate.month - 1]} ${_selectedDate.year}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.hoy),
      body: AmbientBackground(
        child: AnimatedScreenBody(
          child: RefreshIndicator(
            onRefresh: _refreshSummary,
            color: NutrifotoColors.primary,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2A2866), Color(0xFF7A3DF2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _ambientController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _HomeHeaderPainter(
                                    progress: _ambientController.value,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _TopIconButton(
                                      onTap: () => Navigator.pushNamed(context, AppRoutes.perfil),
                                    ),
                                    const Spacer(),
                                    _HeaderQuickActions(
                                      onTapPlan: () => Navigator.pushNamed(context, AppRoutes.plan),
                                      onTapAchievements: () => Navigator.pushNamed(context, AppRoutes.achievements),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '¡Hola! $greeting',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _WeekArrowButton(
                                      icon: Icons.chevron_left,
                                      onTap: () => _shiftWeek(-1),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        selectedDateTitle,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _WeekArrowButton(
                                      icon: Icons.chevron_right,
                                      onTap: () => _shiftWeek(1),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 600),
                                  child: _KcalRing(
                                    key: ValueKey(dateKey),
                                    kcal: _kcal,
                                    goal: _kcalGoal,
                                    progress: kcalPct,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                _MacroSummary(
                                  proteinCurrent: proteinG,
                                  proteinTarget: proteinTarget,
                                  carbsCurrent: carbsG,
                                  carbsTarget: carbsTarget,
                                  fatsCurrent: fatG,
                                  fatsTarget: fatTarget,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: weekDays
                                      .map(
                                        (day) => _DayChip(
                                          date: day,
                                          selected: day == _selectedDate,
                                          onTap: () => _changeDay(day),
                                        ),
                                      )
                                      .toList(),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x229F8CFF),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.lightbulb_outline_rounded,
                                        size: 14,
                                        color: Color(0xFFD7DBFF),
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: _DynamicTip(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          // AI Coach Suggestions
                          _SmartSuggestions(
                            currentKcal: _kcal,
                            goalKcal: _kcalGoal,
                            protein: _proteinTotal,
                            carbs: _carbsTotal,
                            fat: _fatTotal,
                            services: widget.services,
                          ),
                          const SizedBox(height: 12),
                          // Streak indicator
                          if (_currentStreak > 0 || _totalDays > 0)
                            _StreakIndicator(
                              streak: _currentStreak,
                              totalDays: _totalDays,
                            ),
                          const SizedBox(height: 6),
                          // Skeleton loaders during loading
                          if (_isLoading)
                            ...List.generate(3, (_) => SkeletonMealCard())
                          else
                            ...MealSlot.values.toList().asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final slot = entry.value;
                              return _AnimatedMealEntry(
                                index: index,
                                child: _MealCard(
                                  label: slot.label,
                                  mealSlot: slot,
                                  kcal: _mealKcal[slot] ?? 0,
                                  icon: _iconForMeal(slot),
                                  entries: _mealEntries[slot] ?? const [],
                                  onTapAdd: () {
                                    _openCameraFirst(slot);
                                  },
                                  onDeleteEntry: _deleteEntry,
                                  onDuplicateEntry: _duplicateEntry,
                                  onSubstituteEntry: _openSubstitution,
                                  onMoveEntry: _moveEntry,
                                  onTapEntry: _showEditSheet,
                                  onMoreEntry: _showEntryOptions,
                                  onPaste: () => _pasteEntry(slot),
                                  services: widget.services,
                                ),
                              );
                            }),
                          // Goal celebration
                          if (kcalPct >= 1.0 && !_isLoading)
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.9 + (value * 0.1),
                                  child: Opacity(
                                    opacity: value.clamp(0, 1),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('🎉', style: TextStyle(fontSize: 22)),
                                          SizedBox(width: 10),
                                          Text(
                                            '¡Meta de calorías alcanzada!',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      
    );
  }
}

// (Replaced by Camera-First flow)



class _TopIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TopIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}

class _HeaderQuickActions extends StatelessWidget {
  final VoidCallback onTapPlan;
  final VoidCallback onTapAchievements;

  const _HeaderQuickActions({
    required this.onTapPlan,
    required this.onTapAchievements,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _HeaderActionIcon(
            icon: Icons.calendar_today_rounded,
            tooltip: 'Mi Plan',
            onTap: onTapPlan,
          ),
          _HeaderActionIcon(
            icon: Icons.emoji_events_rounded,
            tooltip: 'Logros',
            onTap: onTapAchievements,
          ),
        ],
      ),
    );
  }
}

class _HeaderActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 32,
          child: Icon(icon, size: 21, color: Colors.white),
        ),
      ),
    );
  }
}

class _WeekArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _WeekArrowButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _KcalRing extends StatelessWidget {
  final double kcal;
  final double goal;
  final double progress;

  const _KcalRing({
    super.key,
    required this.kcal,
    required this.goal,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final progressVal = progress.clamp(0.0, 1.0);
    
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Glow
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: NutrifotoColors.primary.withValues(alpha: 0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progressVal),
            duration: const Duration(seconds: 2),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return SizedBox(
                width: 130,
                height: 130,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 12,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              );
            },
          ),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                kcal.round().toString(),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              Text(
                'de ${goal.round()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Clase para posible uso futuro
// class _MacroPill extends StatelessWidget {
//   final int value;
//   final String label;
//   final Color color;
//
//   const _MacroPill({required this.value, required this.label, required this.color});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//       decoration: BoxDecoration(
//         color: Colors.white.withValues(alpha: 0.1),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.white24),
//       ),
//       child: Column(
//         children: [
//           Text(
//             '${value} g',
//             style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
//           ),
//           Text(
//             label,
//             style: const TextStyle(fontSize: 10, color: Colors.white70),
//           ),
//         ],
//       ),
//     );
//   }
// }

class _MacroSummary extends StatelessWidget {
  final double proteinCurrent;
  final double proteinTarget;
  final double carbsCurrent;
  final double carbsTarget;
  final double fatsCurrent;
  final double fatsTarget;

  const _MacroSummary({
    required this.proteinCurrent,
    required this.proteinTarget,
    required this.carbsCurrent,
    required this.carbsTarget,
    required this.fatsCurrent,
    required this.fatsTarget,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      opacity: 0.08,
      borderRadius: BorderRadius.circular(20),
      child: Semantics(
        label: 'Resumen de macronutrientes',
        container: true,
        child: Row(
          children: [
            Expanded(
              child: _MacroCell(
                current: proteinCurrent,
                target: proteinTarget,
                title: 'Proteína',
                color: const Color(0xFF66BEFF),
                icon: Icons.open_with,
              ),
            ),
            const _MacroDivider(),
            Expanded(
              child: _MacroCell(
                current: carbsCurrent,
                target: carbsTarget,
                title: 'Carbos',
                color: const Color(0xFFFFD35F),
                icon: Icons.grain,
              ),
            ),
            const _MacroDivider(),
            Expanded(
              child: _MacroCell(
                current: fatsCurrent,
                target: fatsTarget,
                title: 'Grasas',
                color: const Color(0xFFD8C8FF),
                icon: Icons.opacity_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroDivider extends StatelessWidget {
  const _MacroDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white24,
    );
  }
}

class _MacroCell extends StatelessWidget {
  final double current;
  final double target;
  final String title;
  final Color color;
  final IconData icon;

  const _MacroCell({
    required this.current,
    required this.target,
    required this.title,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (target <= 0 ? 0 : current / target).clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: current.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: '/${target.round()}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 4,
            value: pct,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 42,
        child: Column(
          children: [
            Text(
              labels[date.weekday - 1],
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealCard extends StatefulWidget {
  final String label;
  final MealSlot mealSlot;
  final double kcal;
  final IconData icon;
  final List<DiaryEntry> entries;
  final VoidCallback onTapAdd;
  final Function(String)? onDeleteEntry;
  final Function(DiaryEntry)? onDuplicateEntry;
  final Function(DiaryEntry)? onSubstituteEntry;
  final Function(DiaryEntry, MealSlot)? onMoveEntry;
  final Function(DiaryEntry)? onTapEntry;
  final Function(DiaryEntry)? onMoreEntry;
  final VoidCallback? onPaste;
  final AppServices? services;

  const _MealCard({
    required this.label,
    required this.mealSlot,
    required this.kcal,
    required this.icon,
    required this.entries,
    required this.onTapAdd,
    this.onDeleteEntry,
    this.onDuplicateEntry,
    this.onSubstituteEntry,
    this.onMoveEntry,
    this.onTapEntry,
    this.onMoreEntry,
    this.onPaste,
    this.services,
  });

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  Color _getAccentForMeal(String label) {
    switch (label) {
      case 'Desayuno':
        return const Color(0xFFFFC766);
      case 'Almuerzo':
        return const Color(0xFF6EEB8E);
      case 'Cena':
        return const Color(0xFF7FA6FF);
      case 'Once':
        return const Color(0xFFD28BFF);
      case 'Snack':
        return const Color(0xFFFFA98A);
      default:
        return const Color(0xFFBFA2FF);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuad),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _controller.forward();
  void _onTapUp(TapUpDetails _) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    final accent = _getAccentForMeal(widget.label);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentBlockColor = Color.alphaBlend(
      (isDark ? Colors.black : Colors.white).withValues(
        alpha: isDark ? 0.16 : 0.14,
      ),
      accent,
    );
    const logoIconColor = Colors.white;
    final plusIconColor = isDark ? const Color(0xFF121826) : Colors.white;
    final titleColor = isDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final secondaryColor = isDark
        ? Colors.white.withValues(alpha: 0.82)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72);

    return DragTarget<DiaryEntry>(
      onWillAcceptWithDetails: (details) => details.data.mealSlot != widget.mealSlot,
      onAcceptWithDetails: (details) {
        widget.onMoveEntry?.call(details.data, widget.mealSlot);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.onTapAdd,
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isHovered
                    ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isHovered
                      ? accent
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.11)
                          : Colors.black.withValues(alpha: 0.05)),
                  width: isHovered ? 2 : 1,
                ),
                boxShadow: [
                  if (!isHovered)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  if (isHovered)
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: accentBlockColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.2),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(widget.icon, size: 32, color: logoIconColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.kcal.toStringAsFixed(0)} kcal',
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // BOTÓN: Sugerencias IA Contextuales
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pushNamed(
                          context,
                          AppRoutes.recipes,
                          arguments: {'mealSlot': widget.mealSlot},
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: NutrifotoColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: NutrifotoColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.auto_awesome, size: 20, color: NutrifotoColors.primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Paste button (if clipboard has data)
                    if (MealClipboard.hasData && widget.onPaste != null)
                      GestureDetector(
                        onTap: widget.onPaste,
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.paste_rounded, size: 22, color: Colors.blue),
                        ),
                      ),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: accentBlockColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.24),
                            blurRadius: 9,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(Icons.add, size: 28, color: plusIconColor),
                    ),
                  ],
                ),
                if (widget.entries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      children: [
                        ...widget.entries
                            .take(3)
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SwipeableFoodCard(
                                  entry: entry,
                                  accentColor: accent,
                                  onDelete: () => widget.onDeleteEntry?.call(entry.id),
                                  onDuplicate: () => widget.onDuplicateEntry?.call(entry),
                                  onTapSubstitute: widget.services != null
                                      ? () => widget.onSubstituteEntry?.call(entry)
                                      : null,
                                  onTap: () => widget.onTapEntry?.call(entry),
                                  onMore: () => widget.onMoreEntry?.call(entry),
                                ),
                              ),
                            ),
                        if (widget.entries.length > 3)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'y ${widget.entries.length - 3} mas...',
                              style: TextStyle(
                                color: secondaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Sin comidas registradas aun',
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  },
);
  }
}



class _AnimatedMealEntry extends StatelessWidget {
  final int index;
  final Widget child;

  const _AnimatedMealEntry({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final duration = Duration(milliseconds: 600 + (index * 100));
    return TweenAnimationBuilder<double>(
      duration: duration,
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, _) {
        final clampedValue = value.clamp(0.0, 1.0);
        return Opacity(
          opacity: clampedValue,
          child: Transform.translate(
            offset: Offset(0, (1 - clampedValue) * 20),
            child: Transform.scale(
              scale: 0.95 + (clampedValue * 0.05),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeaderPainter extends CustomPainter {
  final double progress;

  _HomeHeaderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x33FFFFFF);

    for (var i = 0; i < 3; i++) {
      final path = Path();
      final baseY = 70.0 + (i * 44.0);
      path.moveTo(-20, baseY);
      for (double x = -20; x <= size.width + 20; x += 14) {
        final y = baseY + math.sin((x / 75) + (progress * 6) + i) * (7 + i * 2);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, linePaint);
    }

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x36FFFFFF);
    for (var i = 0; i < 14; i++) {
      final x = ((i * 39) + (progress * 120)) % (size.width + 30) - 15;
      final y = 44 + (i % 5) * 36 + math.cos(progress * 5 + i) * 4;
      canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HomeHeaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
// ============================================================================
// AI COACH CARD - Recomendaciones inteligentes con Gemini
// ============================================================================

class _SmartSuggestions extends StatefulWidget {
  final double currentKcal;
  final double goalKcal;
  final double protein;
  final double carbs;
  final double fat;
  final AppServices services;

  const _SmartSuggestions({
    required this.currentKcal,
    required this.goalKcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.services,
  });

  @override
  State<_SmartSuggestions> createState() => _SmartSuggestionsState();
}

class _SmartSuggestionsState extends State<_SmartSuggestions> {
  String? _advice;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchAdvice();
  }

  @override
  void didUpdateWidget(_SmartSuggestions oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Solo refrescar si el cambio de calorías es significativo (>50 kcal)
    if ((widget.currentKcal - oldWidget.currentKcal).abs() > 50) {
      _fetchAdvice();
    }
  }

  Future<void> _fetchAdvice() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final hour = DateTime.now().hour;
      final timeContext = hour < 12 ? 'mañana' : (hour < 18 ? 'tarde' : 'noche');

      final advice = await widget.services.geminiNlpService.generateNutritionalAdvice(
        kcalLeft: widget.goalKcal - widget.currentKcal,
        proteinLeft: (widget.goalKcal * 0.30 / 4) - widget.protein,
        carbsLeft: (widget.goalKcal * 0.40 / 4) - widget.carbs,
        fatLeft: (widget.goalKcal * 0.30 / 9) - widget.fat,
        userName: 'Nutrifoto User',
        timeOfDay: timeContext,
      );
      
      if (mounted) {
        setState(() {
          _advice = advice ?? '¡Sigue así con tu registro hoy!';
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching AI advice: $e');
      if (mounted) {
        setState(() {
          _advice = 'No pude conectar con el Coach. ¡Tú puedes!';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF2D1B69), const Color(0xFF1A1A2E)]
            : [const Color(0xFFF0E7FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: NutrifotoColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: NutrifotoColors.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: NutrifotoColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'COACH IA',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: NutrifotoColors.primary,
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: NutrifotoColors.primary),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: NutrifotoColors.primary),
                  onPressed: _fetchAdvice,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _advice ?? 'Analizando tu día para darte el mejor consejo...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STREAK INDICATOR - Indicador de racha y motivación
// ============================================================================

class _StreakIndicator extends StatelessWidget {
  final int streak;
  final int totalDays;

  const _StreakIndicator({
    required this.streak,
    required this.totalDays,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withValues(alpha: isDark ? 0.25 : 0.12),
            const Color(0xFFFF9F1C).withValues(alpha: isDark ? 0.15 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Streak fire
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF6B35),
                size: 22,
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$streak',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF6B35),
                    ),
                  ),
                  Text(
                    streak == 1 ? 'día seguido' : 'días seguidos',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 1,
            height: 32,
            color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          // Total days trophy
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFFFFD700),
                size: 22,
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$totalDays',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                  Text(
                    totalDays == 1 ? 'día registrado' : 'días registrados',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DynamicTip extends StatelessWidget {
  const _DynamicTip();

  static const _tips = [
    'Batido de proteína natural',
    'Bebe 2L de agua al día',
    'Camina 10,000 pasos',
    'Consume más fibra',
    'Evita azúcares añadidos',
    'Prueba el ayuno intermitente',
    'Duerme 8 horas diarias',
    'Reduce el consumo de sal',
  ];

  @override
  Widget build(BuildContext context) {
    final tip = _tips[math.Random().nextInt(_tips.length)];
    return Text(
      tip,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }
}
