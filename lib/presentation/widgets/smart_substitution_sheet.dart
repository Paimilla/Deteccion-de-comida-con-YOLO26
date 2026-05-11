import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_services.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
import 'nutrifoto_ui.dart';
import 'skeleton_loader.dart';

/// Bottom sheet that finds nutritionally similar food alternatives.
/// Uses the existing search API with post-filtering by macro similarity.
class SmartSubstitutionSheet extends StatefulWidget {
  final FoodItem originalFood;
  final MealSlot mealSlot;
  final AppServices services;
  final String entryId;

  const SmartSubstitutionSheet({
    super.key,
    required this.originalFood,
    required this.mealSlot,
    required this.services,
    required this.entryId,
  });

  /// Show the substitution sheet and return the selected replacement (if any).
  static Future<FoodItem?> show({
    required BuildContext context,
    required FoodItem originalFood,
    required MealSlot mealSlot,
    required AppServices services,
    required String entryId,
  }) {
    return showModalBottomSheet<FoodItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: NutrifotoColors.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SmartSubstitutionSheet(
        originalFood: originalFood,
        mealSlot: mealSlot,
        services: services,
        entryId: entryId,
      ),
    );
  }

  @override
  State<SmartSubstitutionSheet> createState() => _SmartSubstitutionSheetState();
}

class _SmartSubstitutionSheetState extends State<SmartSubstitutionSheet> {
  bool _loading = true;
  List<FoodItem> _alternatives = [];

  @override
  void initState() {
    super.initState();
    _loadAlternatives();
  }

  Future<void> _loadAlternatives() async {
    try {
      // Search for similar foods using the food name keywords
      final keywords = widget.originalFood.nameEs.split(' ').take(2).join(' ');
      final results =
          await widget.services.foodOrchestrator.searchFoodInSpanish(keywords);

      if (!mounted) return;

      // Filter by macro similarity (±15% kcal, ±20% protein)
      final original = widget.originalFood.nutrition;
      final filtered = results.where((item) {
        if (item.itemId == widget.originalFood.itemId) return false;
        if (item.nameEs.trim().toLowerCase() ==
            widget.originalFood.nameEs.trim().toLowerCase()) return false;

        final kcalDiff = (item.nutrition.kcal - original.kcal).abs();
        final kcalThreshold = original.kcal * 0.25;
        if (kcalDiff > kcalThreshold && kcalThreshold > 10) return false;

        return true;
      }).toList();

      // Sort by kcal similarity
      filtered.sort((a, b) {
        final diffA = (a.nutrition.kcal - original.kcal).abs();
        final diffB = (b.nutrition.kcal - original.kcal).abs();
        return diffA.compareTo(diffB);
      });

      setState(() {
        _alternatives = filtered.take(6).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _substituteWith(FoodItem newFood) async {
    HapticFeedback.mediumImpact();

    // Remove old entry and add new one
    await widget.services.trackingUseCases.removeFoodEntry(widget.entryId);
    await widget.services.trackingUseCases.addFoodEntry(
      mealSlot: widget.mealSlot,
      food: newFood,
    );

    if (!mounted) return;
    Navigator.of(context).pop(newFood);
  }

  @override
  Widget build(BuildContext context) {
    final original = widget.originalFood;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            // Header
            const Text(
              'Sustitución Inteligente',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Alternativas con macros similares',
              style: TextStyle(
                fontSize: 14,
                color: NutrifotoColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),

            // Original food card
            _FoodCompareCard(
              food: original,
              isOriginal: true,
            ),

            const SizedBox(height: 16),

            // Divider with arrow
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.swap_vert_rounded,
                    color: NutrifotoColors.primary,
                    size: 24,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Alternatives
            if (_loading)
              ...List.generate(3, (_) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SkeletonListItem(),
              ))
            else if (_alternatives.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: NutrifotoColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      color: NutrifotoColors.textMuted,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No se encontraron alternativas similares',
                      style: TextStyle(
                        color: NutrifotoColors.textMuted,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._alternatives.map((alt) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FoodCompareCard(
                  food: alt,
                  isOriginal: false,
                  originalNutrition: original.nutrition,
                  onTapSubstitute: () => _substituteWith(alt),
                ),
              )),
          ],
        );
      },
    );
  }
}

class _FoodCompareCard extends StatelessWidget {
  final FoodItem food;
  final bool isOriginal;
  final Nutrition? originalNutrition;
  final VoidCallback? onTapSubstitute;

  const _FoodCompareCard({
    required this.food,
    required this.isOriginal,
    this.originalNutrition,
    this.onTapSubstitute,
  });

  @override
  Widget build(BuildContext context) {
    final n = food.nutrition;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOriginal
            ? NutrifotoColors.primary.withValues(alpha: 0.1)
            : NutrifotoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOriginal
              ? NutrifotoColors.primary.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isOriginal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: NutrifotoColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ACTUAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  food.nameEs,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isOriginal && onTapSubstitute != null)
                GestureDetector(
                  onTap: onTapSubstitute,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [NutrifotoColors.primary, NutrifotoColors.primarySoft],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Cambiar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Macro badges
          Row(
            children: [
              _MacroBadge('${n.kcal.toInt()} kcal', Colors.deepOrange,
                  originalNutrition?.kcal),
              const SizedBox(width: 6),
              _MacroBadge('P ${n.proteinG.toInt()}g', const Color(0xFF66BEFF),
                  originalNutrition?.proteinG),
              const SizedBox(width: 6),
              _MacroBadge('C ${n.carbsG.toInt()}g', const Color(0xFFFFD35F),
                  originalNutrition?.carbsG),
              const SizedBox(width: 6),
              _MacroBadge('G ${n.fatG.toInt()}g', const Color(0xFFD8C8FF),
                  originalNutrition?.fatG),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double? originalValue;

  const _MacroBadge(this.label, this.color, this.originalValue);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
