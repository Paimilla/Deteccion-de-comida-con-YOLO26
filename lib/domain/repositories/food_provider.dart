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
}
