import '../models/nutrition_models.dart';

abstract class BarcodeProvider {
  Future<FoodItem?> findByBarcode(String barcode);
}

abstract class FoodSearchProvider {
  Future<List<FoodItem>> searchFood(String textEn);
}

abstract class RecipeProvider {
  Future<List<FoodItem>> searchRecipes(String ingredientEn);
}

abstract class VisionProvider {
  Future<FoodItem?> classifyFood(String imagePath);
}

abstract class TranslationService {
  Future<String> toEnglish(String textEs);
  Future<String> toSpanish(String textEn);
  Future<List<String>> translateBatch({
    required List<String> texts,
    required String source,
    required String target,
  });
  Future<List<String>> translateAndDescribeBatch({
    required List<String> titles,
    required String source,
    required String target,
  });
}
