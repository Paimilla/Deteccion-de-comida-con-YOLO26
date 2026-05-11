import '../../domain/models/nutrition_models.dart';

class LocalChileProvider {
  final Map<String, dynamic> _dataset;

  LocalChileProvider(this._dataset);

  FoodItem? findByClassName(String className) {
    final key = className.trim().toLowerCase();
    final row = _dataset[key];
    if (row is! Map<String, dynamic>) {
      return null;
    }

    final kcal = (row['kcal'] as num?)?.toDouble() ?? 0;
    final protein = (row['protein_g'] as num?)?.toDouble() ?? 0;
    final carbs = (row['carbs_g'] as num?)?.toDouble() ?? 0;
    final fat = (row['fat_g'] as num?)?.toDouble() ?? 0;

    return FoodItem(
      source: FoodSource.localChile,
      itemId: row['id']?.toString() ?? key,
      nameEs: row['name_es']?.toString() ?? className,
      nameEn: row['name_en']?.toString(),
      portion: const Portion(amount: 100, unit: 'g'),
      nutrition: Nutrition(
        kcal: kcal,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      ),
      metadata: {'dataset': 'chile_44'},
    );
  }
}
