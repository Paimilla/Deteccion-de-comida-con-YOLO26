enum FoodSource {
  localChile,
  openFoodFacts,
  usda,
  spoonacular,
  aiVision,
  unknown,
}

class Portion {
  final double amount;
  final String unit;

  const Portion({required this.amount, required this.unit});
}

class Nutrition {
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const Nutrition({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

class FoodItem {
  final FoodSource source;
  final String itemId;
  final String nameEs;
  final String? nameEn;
  final Portion portion;
  final Nutrition nutrition;
  final double confidence;
  final String? imageUrl;
  final Map<String, dynamic> metadata;

  const FoodItem({
    required this.source,
    required this.itemId,
    required this.nameEs,
    this.nameEn,
    required this.portion,
    required this.nutrition,
    this.confidence = 1.0,
    this.imageUrl,
    this.metadata = const {},
  });

  FoodItem copyWith({
    FoodSource? source,
    String? itemId,
    String? nameEs,
    String? nameEn,
    Portion? portion,
    Nutrition? nutrition,
    double? confidence,
    String? imageUrl,
    Map<String, dynamic>? metadata,
  }) {
    return FoodItem(
      source: source ?? this.source,
      itemId: itemId ?? this.itemId,
      nameEs: nameEs ?? this.nameEs,
      nameEn: nameEn ?? this.nameEn,
      portion: portion ?? this.portion,
      nutrition: nutrition ?? this.nutrition,
      confidence: confidence ?? this.confidence,
      imageUrl: imageUrl ?? this.imageUrl,
      metadata: metadata ?? this.metadata,
    );
  }
}
