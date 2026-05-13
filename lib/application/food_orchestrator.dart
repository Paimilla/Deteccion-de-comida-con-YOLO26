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

    if (results.isEmpty) return const [];

    final List<String> namesToProcess = results.map((e) => e.nameEn ?? e.nameEs).toList();
    final processedTexts = await translationService.translateAndDescribeBatch(
      titles: namesToProcess,
      source: 'inglés',
      target: 'español',
    );

    final translatedResults = <FoodItem>[];
    for (int i = 0; i < results.length; i++) {
      final item = results[i];
      String nameEs = item.nameEs;
      String shortDescEs = 'Un alimento nutritivo detectado en la búsqueda global.';

      if (i < processedTexts.length) {
        final parts = processedTexts[i].split('|');
        nameEs = parts[0].trim();
        if (parts.length > 1) {
          shortDescEs = parts[1].trim();
        }
      }

      final newMetadata = Map<String, dynamic>.from(item.metadata);
      newMetadata['short_description_es'] = shortDescEs;

      translatedResults.add(
        item.copyWith(
          nameEs: nameEs,
          metadata: newMetadata,
        ),
      );
    }
    return translatedResults;
  }

  Future<List<FoodItem>> searchRecipesInSpanish(String ingredientEs) async {
    // 1. Traducir ingrediente al inglés para máxima compatibilidad con APIs
    final ingredientEn = await translationService.toEnglish(ingredientEs);
    
    // 2. Buscar recetas
    final results = await recipeProvider.searchRecipes(ingredientEn);
    
    if (results.isEmpty) {
      if (ingredientEn != ingredientEs) {
        return recipeProvider.searchRecipes(ingredientEs);
      }
      return const [];
    }

    // 3. Traducir títulos y generar descripciones cortas (mucho más profesional)
    final List<String> itemsToProcess = results.map((e) => e.nameEn ?? e.nameEs).toList();
    
    // Pedimos a Gemini que traduzca y cree una descripción breve de una línea
    final processedTexts = await translationService.translateAndDescribeBatch(
      titles: itemsToProcess,
      source: 'inglés',
      target: 'español',
    );

    // 4. Reconstruir los FoodItems
    final translatedResults = <FoodItem>[];
    for (int i = 0; i < results.length; i++) {
      final item = results[i];
      String nameEs = item.nameEs;
      String shortDescEs = 'Una opción nutritiva y equilibrada para tu registro.';

      if (i < processedTexts.length) {
        final parts = processedTexts[i].split('|');
        nameEs = parts[0].trim();
        if (parts.length > 1) {
          shortDescEs = parts[1].trim();
        }
      }

      final newMetadata = Map<String, dynamic>.from(item.metadata);
      newMetadata['short_description_es'] = shortDescEs;

      translatedResults.add(
        item.copyWith(
          nameEs: nameEs,
          metadata: newMetadata,
        ),
      );
    }
    
    return translatedResults;
  }

  /// Traduce los detalles de una receta (summary e instrucciones) on-demand.
  Future<FoodItem> translateRecipeDetails(FoodItem item) async {
    final summary = item.metadata['summary']?.toString();
    final instructions = item.metadata['instructions']?.toString();
    
    if ((summary == null || summary.isEmpty) && (instructions == null || instructions.isEmpty)) {
      return item;
    }

    final toTranslate = [summary ?? '', instructions ?? ''];
    final translated = await translationService.translateBatch(
      texts: toTranslate,
      source: 'inglés',
      target: 'español',
    );

    final newMetadata = Map<String, dynamic>.from(item.metadata);
    if (translated.isNotEmpty) {
      newMetadata['summary_es'] = translated[0];
      if (translated.length > 1) {
        newMetadata['instructions_es'] = translated[1];
      }
    }

    return item.copyWith(metadata: newMetadata);
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
