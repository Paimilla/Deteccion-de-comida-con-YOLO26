import '../domain/models/nutrition_models.dart';
import '../domain/repositories/food_provider.dart';
import '../infrastructure/providers/local_chile_provider.dart';

class FoodOrchestrator {
  final LocalChileProvider localChileProvider;
  final BarcodeProvider barcodeProvider;
  final FoodSearchProvider usdaProvider;
  final RecipeProvider recipeProvider;
  final TranslationService translationService;
  final VisionProvider visionProvider;

  FoodOrchestrator({
    required this.localChileProvider,
    required this.barcodeProvider,
    required this.usdaProvider,
    required this.recipeProvider,
    required this.translationService,
    required this.visionProvider,
  });

  Future<FoodItem?> findByBarcode(String barcode) async {
    final openFoodFactsResult = await barcodeProvider.findByBarcode(barcode);
    if (openFoodFactsResult != null) {
      return openFoodFactsResult;
    }

    final fallback = await usdaProvider.searchFood(barcode);
    return fallback.isNotEmpty ? fallback.first : null;
  }

  Future<List<FoodItem>> searchFoodInSpanish(String textEs) async {
    final textEn = await translationService.toEnglish(textEs);
    final results = await usdaProvider.searchFood(textEn);

    final translated = <FoodItem>[];
    for (final item in results) {
      final translatedName = await translationService.toSpanish(
        item.nameEn ?? item.nameEs,
      );
      translated.add(
        FoodItem(
          source: item.source,
          itemId: item.itemId,
          nameEs: translatedName,
          nameEn: item.nameEn,
          portion: item.portion,
          nutrition: item.nutrition,
          confidence: item.confidence,
          imageUrl: item.imageUrl,
          metadata: item.metadata,
        ),
      );
    }
    return translated;
  }

  Future<List<FoodItem>> searchRecipesInSpanish(String ingredientEs) async {
    // Buscar primero con el término en español (OpenFoodFacts lo soporta)
    final results = await recipeProvider.searchRecipes(ingredientEs);
    if (results.isNotEmpty) return results;

    // Si no hay resultados, intentar con traducción al inglés
    final ingredientEn = await translationService.toEnglish(ingredientEs);
    if (ingredientEn != ingredientEs) {
      return recipeProvider.searchRecipes(ingredientEn);
    }
    return results;
  }

  Future<FoodItem?> classifyFromImage(String imagePath) async {
    final result = await visionProvider.classifyFood(imagePath);
    if (result == null) {
      return null;
    }

    final className = result.metadata['class_name']?.toString();
    if (className == null || className.isEmpty) {
      return result;
    }

    final local = localChileProvider.findByClassName(className);
    if (local == null) {
      return result;
    }

    // Si IA no entrega macros completos, se enriquece con base local.
    final isEmptyNutrition =
        result.nutrition.kcal == 0 &&
        result.nutrition.proteinG == 0 &&
        result.nutrition.carbsG == 0 &&
        result.nutrition.fatG == 0;

    if (!isEmptyNutrition) {
      return result;
    }

    return FoodItem(
      source: FoodSource.aiVision,
      itemId: result.itemId,
      nameEs: result.nameEs,
      nameEn: result.nameEn,
      portion: result.portion,
      nutrition: local.nutrition,
      confidence: result.confidence,
      imageUrl: result.imageUrl,
      metadata: result.metadata,
    );
  }

  FoodItem? resolveLocalClass(String className) {
    return localChileProvider.findByClassName(className);
  }
}
