import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/models/tracking_models.dart';
import 'nutrifoto_ui.dart';

class EditFoodEntrySheet extends StatefulWidget {
  final DiaryEntry entry;
  final Function(DiaryEntry) onSave;

  const EditFoodEntrySheet({
    super.key,
    required this.entry,
    required this.onSave,
  });

  @override
  State<EditFoodEntrySheet> createState() => _EditFoodEntrySheetState();
}

class _EditFoodEntrySheetState extends State<EditFoodEntrySheet> {
  late double _amount;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _amount = widget.entry.food.portion.amount;
    _controller = TextEditingController(text: _amount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateAmount(String value) {
    final val = double.tryParse(value);
    if (val != null && val > 0) {
      setState(() => _amount = val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final food = widget.entry.food.withNewAmount(_amount);
    final nutrition = food.nutrition;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Food Title
          Text(
            widget.entry.food.nameEs,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Editando cantidad del alimento',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 24),

          // Amount Input
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: NutrifotoColors.primary,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      suffixText: widget.entry.food.portion.unit,
                      suffixStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    onChanged: _updateAmount,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Nutrients Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NutrientPreview(
                label: 'Kcal',
                value: nutrition.kcal.round().toString(),
                color: Colors.orange,
              ),
              _NutrientPreview(
                label: 'Prot',
                value: '${nutrition.proteinG.toStringAsFixed(1)}g',
                color: Colors.blue,
              ),
              _NutrientPreview(
                label: 'Carb',
                value: '${nutrition.carbsG.toStringAsFixed(1)}g',
                color: Colors.green,
              ),
              _NutrientPreview(
                label: 'Gras',
                value: '${nutrition.fatG.toStringAsFixed(1)}g',
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                final updatedEntry = DiaryEntry(
                  id: widget.entry.id,
                  timestamp: widget.entry.timestamp,
                  mealSlot: widget.entry.mealSlot,
                  food: food,
                );
                widget.onSave(updatedEntry);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: NutrifotoColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Guardar cambios',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientPreview extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NutrientPreview({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: color.withValues(alpha: 0.8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }
}
