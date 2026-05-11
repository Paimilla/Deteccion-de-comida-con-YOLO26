import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/nutrifoto_ui.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/draggable_food_card.dart';
import '../widgets/smart_substitution_sheet.dart';

class PlanScreen extends StatefulWidget {
  final AppServices services;

  const PlanScreen({super.key, required this.services});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen>
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
      duration: const Duration(seconds: 11),
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

  LinearGradient _gradientForMealSlot(MealSlot slot) {
    switch (slot) {
      case MealSlot.desayuno:
        return NutrifotoColors.desayunoGradient;
      case MealSlot.almuerzo:
        return NutrifotoColors.almuerzoGradient;
      case MealSlot.cena:
        return NutrifotoColors.cenaGradient;
      case MealSlot.once:
        return NutrifotoColors.onceGradient;
      case MealSlot.snack:
        return NutrifotoColors.snackGradient;
    }
  }

  IconData _iconForMealSlot(MealSlot slot) {
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
  Widget build(BuildContext context) {
    final selected = _selectedSummary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de Comidas'),
        actions: [
          IconButton(
            tooltip: 'Estadísticas',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.progreso),
            icon: const Icon(Icons.bar_chart_rounded),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.plan),
      body: _loading
          ? AnimatedScreenBody(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildDateSelector(context),
                  const SizedBox(height: 20),
                  ...List.generate(3, (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: SkeletonMealCard(),
                  )),
                ],
              ),
            )
          : selected == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.date_range_outlined, size: 56, color: NutrifotoColors.textMuted),
                      const SizedBox(height: 16),
                      const Text('No hay datos para este día'),
                    ],
                  ),
                )               : AnimatedScreenBody(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isTablet = constraints.maxWidth > 600;

                      final nutritionSummary = _buildNutritionSummary(selected);
                      final mealCards = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Desglose de Comidas',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                          ),
                          const SizedBox(height: 12),
                          ...MealSlot.values.map((slot) {
                            final entries = selected.entries
                                .where((e) => e.mealSlot == slot)
                                .toList();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildMealCard(context, slot, entries),
                            );
                          }),
                        ],
                      );

                      if (isTablet) {
                        // Tablet: 2-column layout
                        return ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          children: [
                            _buildDateSelector(context),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left: Nutrition summary
                                Expanded(child: nutritionSummary),
                                const SizedBox(width: 16),
                                // Right: Meal cards
                                Expanded(flex: 2, child: mealCards),
                              ],
                            ),
                          ],
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        children: [
                          _buildDateSelector(context),
                          const SizedBox(height: 20),
                          nutritionSummary,
                          const SizedBox(height: 24),
                          mealCards,
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => _onDaySelected(_selectedDay.subtract(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_left_rounded),
              splashRadius: 24,
            ),
            Text(
              _fmtDate(_selectedDay),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
            ),
            IconButton(
              onPressed: _selectedDay.isBefore(_onlyDate(DateTime.now()))
                  ? () => _onDaySelected(_selectedDay.add(const Duration(days: 1)))
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
              splashRadius: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionSummary(DailySummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Totales del Día',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: NutrifotoColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: NutrifotoColors.heroGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${summary.kcalTotal.toStringAsFixed(0)} kcal',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMacroCell('P', summary.proteinTotal, 'g', Colors.amber),
                _buildMacroCell('C', summary.carbsTotal, 'g', Colors.blue),
                _buildMacroCell('G', summary.fatTotal, 'g', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroCell(String label, double value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: NutrifotoColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${value.toStringAsFixed(1)}$unit',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealCard(BuildContext context, MealSlot slot, List<DiaryEntry> entries) {
    final gradient = _gradientForMealSlot(slot);
    final icon = _iconForMealSlot(slot);
    final totalKcal = entries.fold<double>(0, (sum, e) => sum + e.food.nutrition.kcal);

    // ── Envolvemos cada MealCard en un DragTarget para recibir drops ──
    return MealSlotDragTarget(
      targetSlot: slot,
      gradient: gradient,
      onFoodDropped: (droppedEntry) => _handleDrop(droppedEntry, slot),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(
            context,
            AppRoutes.scannerCamera,
            arguments: {'mealSlot': slot},
          ).then((_) {
            if (mounted) _loadSelectedDay();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slot.label.toUpperCase(),
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                            Text(
                              '${entries.length} alimento${entries.length == 1 ? '' : 's'}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${totalKcal.toStringAsFixed(0)} kcal',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Items list ──
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agregar alimento',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: entries.asMap().entries.map((e) {
                        final idx = e.key;
                        final entry = e.value;
                        final isLast = idx == entries.length - 1;
                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                          child: DraggableFoodCard(
                            entry: entry,
                            accentColor: gradient.colors.first,
                            // ── Eliminar con Undo ──
                            onDelete: () => _deleteWithUndo(entry),
                            onDuplicate: () async {
                              HapticFeedback.lightImpact();
                              await widget.services.trackingUseCases.duplicateFoodEntry(entry);
                              if (mounted) {
                                await _loadSelectedDay();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                                          const SizedBox(width: 8),
                                          Text('${entry.food.nameEs} duplicado'),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            onTapSubstitute: () async {
                              final result = await SmartSubstitutionSheet.show(
                                context: context,
                                originalFood: entry.food,
                                mealSlot: entry.mealSlot,
                                services: widget.services,
                                entryId: entry.id,
                              );
                              if (result != null && mounted) {
                                await _loadSelectedDay();
                              }
                            },
                            // ── Menú de 3 puntos ──
                            onCopyToOtherDay: () => _showCopyToDayDialog(entry),
                            onSaveAsFavorite: () => _saveFavorite(entry),
                            onEditPortion: () => _showEditPortionDialog(entry),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Drag & Drop handler
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleDrop(DiaryEntry droppedEntry, MealSlot targetSlot) async {
    final original = await widget.services.trackingUseCases.moveFoodEntry(
      entryId: droppedEntry.id,
      targetSlot: targetSlot,
    );

    if (!mounted) return;
    await _loadSelectedDay();

    if (original != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.swap_horiz, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${droppedEntry.food.nameEs} movido a ${targetSlot.label}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'DESHACER',
            textColor: NutrifotoColors.accentBlue,
            onPressed: () async {
              // Undo: restaurar la entrada original
              await widget.services.trackingUseCases.undoDelete(original);
              // Eliminar la copia movida
              final currentEntries = await widget.services.trackingUseCases
                  .getDailySummary(_selectedDay);
              final movedEntry = currentEntries.entries.where(
                (e) => e.food.itemId == original.food.itemId && e.mealSlot == targetSlot,
              ).lastOrNull;
              if (movedEntry != null) {
                await widget.services.trackingUseCases.removeFoodEntry(movedEntry.id);
              }
              if (mounted) _loadSelectedDay();
            },
          ),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Eliminar con Undo (SnackBar)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _deleteWithUndo(DiaryEntry entry) async {
    HapticFeedback.mediumImpact();
    await widget.services.trackingUseCases.removeFoodEntry(entry.id);
    if (!mounted) return;
    await _loadSelectedDay();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${entry.food.nameEs} eliminado',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: NutrifotoColors.accentBlue,
          onPressed: () async {
            await widget.services.trackingUseCases.undoDelete(entry);
            if (mounted) _loadSelectedDay();
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Menú 3 puntos: Copiar a otro día
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showCopyToDayDialog(DiaryEntry entry) async {
    final targetDay = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Copiar "${entry.food.nameEs}" a:',
    );

    if (targetDay == null || !mounted) return;

    // Seleccionar comida destino
    final targetSlot = await showDialog<MealSlot>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('¿A qué comida?'),
        children: MealSlot.values.map((slot) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, slot),
            child: Row(
              children: [
                Icon(_iconForMealSlot(slot), size: 20),
                const SizedBox(width: 12),
                Text(slot.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (targetSlot == null || !mounted) return;

    await widget.services.trackingUseCases.copyFoodToDay(
      food: entry.food,
      targetDay: targetDay,
      targetSlot: targetSlot,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entry.food.nameEs} copiado a ${_fmtDate(targetDay)} (${targetSlot.label})'),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Menú 3 puntos: Guardar como favorito
  // ═══════════════════════════════════════════════════════════════════════════

  void _saveFavorite(DiaryEntry entry) {
    HapticFeedback.lightImpact();
    // TODO: Implementar persistencia de favoritos cuando el repositorio lo soporte
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.favorite, color: Color(0xFFFF6B6B), size: 18),
            const SizedBox(width: 8),
            Text('${entry.food.nameEs} guardado como favorito'),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Menú 3 puntos: Editar porción rápida
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _showEditPortionDialog(DiaryEntry entry) async {
    final controller = TextEditingController(
      text: entry.food.portion.amount.toStringAsFixed(0),
    );

    final newAmount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar porción: ${entry.food.nameEs}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Cantidad (${entry.food.portion.unit})',
            suffixText: entry.food.portion.unit,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              Navigator.pop(ctx, parsed);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newAmount == null || newAmount <= 0 || !mounted) return;

    // Calcular ratio de nutrientes proporcional
    final oldAmount = entry.food.portion.amount;
    final ratio = newAmount / (oldAmount > 0 ? oldAmount : 100);

    final updatedFood = FoodItem(
      source: entry.food.source,
      itemId: entry.food.itemId,
      nameEs: entry.food.nameEs,
      nameEn: entry.food.nameEn,
      portion: Portion(amount: newAmount, unit: entry.food.portion.unit),
      nutrition: Nutrition(
        kcal: entry.food.nutrition.kcal * ratio,
        proteinG: entry.food.nutrition.proteinG * ratio,
        carbsG: entry.food.nutrition.carbsG * ratio,
        fatG: entry.food.nutrition.fatG * ratio,
      ),
      confidence: entry.food.confidence,
      imageUrl: entry.food.imageUrl,
      metadata: entry.food.metadata,
    );

    // Eliminar vieja y crear nueva
    await widget.services.trackingUseCases.removeFoodEntry(entry.id);
    await widget.services.trackingUseCases.addFoodEntry(
      mealSlot: entry.mealSlot,
      food: updatedFood,
      timestamp: entry.timestamp,
    );

    if (mounted) {
      await _loadSelectedDay();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Porción actualizada a ${newAmount.toStringAsFixed(0)}${entry.food.portion.unit}'),
          ),
        );
      }
    }
  }
}
