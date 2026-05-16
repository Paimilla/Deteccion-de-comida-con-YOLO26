import 'package:flutter/foundation.dart';

import '../domain/models/nutrition_models.dart';
import '../domain/repositories/food_provider.dart';
import '../infrastructure/providers/local_chile_provider.dart';
import '../infrastructure/services/local_chile_search_service.dart';
import '../infrastructure/services/search_cache_service.dart';
import '../infrastructure/services/smart_recipe_search_service.dart';

class FoodOrchestrator {
  final LocalChileProvider localChileProvider;
  final BarcodeProvider barcodeProvider;
  final FoodSearchProvider usdaProvider;
  final RecipeProvider recipeProvider;
  final TranslationService translationService;
  final VisionProvider visionProvider;
  final SearchCacheService searchCache = SearchCacheService();
  final LocalChileSearchService _localChileSearch = LocalChileSearchService();

  /// In-memory cache for full FoodItem objects (search results)
  final Map<String, List<FoodItem>> _fullItemCache = {};

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
    // 0. Inicializar base de datos local
    await _localChileSearch.initialize();

    // 1. Verificar caché primero (objetos completos en memoria)
    final cacheKey = ingredientEs.toLowerCase();
    final cachedItems = _fullItemCache[cacheKey];
    if (cachedItems != null && cachedItems.isNotEmpty) {
      debugPrint('⚡ Usando ${cachedItems.length} resultados cacheados para "$ingredientEs"');
      return cachedItems;
    }

    final stopwatch = Stopwatch()..start();
    final allResults = <FoodItem>[];
    final seenNames = <String>{}; // Deduplication by name

    // 2. Búsqueda inteligente: expandir términos con sinónimos y categorías
    final searchTerms = SmartRecipeSearchService.expandSearchTerms(ingredientEs);
    debugPrint('🔍 Búsqueda expandida: ${searchTerms.length} términos (${searchTerms.take(3).join(", ")}...)');

    // 3. Buscar en base local chilena primero (sin latencia API)
    for (final term in searchTerms) {
      final localResults = await _localChileSearch.searchLocal(term);
      for (final item in localResults) {
        final key = item.nameEs.toLowerCase().trim();
        if (!seenNames.contains(key)) {
          seenNames.add(key);
          allResults.add(item);
        }
      }
      if (allResults.length >= 8) break; // Limitar búsqueda local
    }

    debugPrint('🇨🇱 Resultados locales: ${allResults.length}');

    // 4. Si no hay resultados locales, buscar en API Edamam
    // Pero solo traducir el primer término para evitar latencia
    if (allResults.isEmpty || allResults.length < 4) {
      // Usar caché de traducciones
      String ingredientEn = searchCache.getTranslation(cacheKey) ?? 
          await translationService.toEnglish(ingredientEs);
      searchCache.setTranslation(cacheKey, ingredientEn);

      final apiResults = await recipeProvider.searchRecipes(ingredientEn);
      for (final item in apiResults) {
        final key = item.nameEs.toLowerCase().trim();
        if (!seenNames.contains(key)) {
          seenNames.add(key);
          allResults.add(item);
        }
      }
      debugPrint('🌐 Resultados API: ${apiResults.length} (${allResults.length} únicos totales)');
    }

    if (allResults.isEmpty) {
      debugPrint('⏱️  Búsqueda: ${stopwatch.elapsedMilliseconds}ms (sin resultados)');
      return const [];
    }

    // 5. Lazy-load: Traducir y describir en background (no esperar)
    // Retornar resultados rápido, actualizar descripciones después
    final translatedResults = await _translateAndCacheResults(allResults);

    stopwatch.stop();
    debugPrint('⏱️  Búsqueda total: ${stopwatch.elapsedMilliseconds}ms (${translatedResults.length} resultados)');

    // Guardar en caché (objetos completos en memoria)
    _fullItemCache[cacheKey] = translatedResults;
    debugPrint('💾 Cacheados ${translatedResults.length} items para "$cacheKey"');

    return translatedResults;
  }

  /// Traduce y enriquece resultados — solo items de APIs externas.
  /// Items locales chilenos ya tienen nombre en español y descripción.
  Future<List<FoodItem>> _translateAndCacheResults(List<FoodItem> items) async {
    // Separar items locales (ya en español) de items API (necesitan traducción)
    final localItems = <FoodItem>[];
    final apiItems = <FoodItem>[];
    
    for (int i = 0; i < items.length; i++) {
      if (items[i].source == FoodSource.localChile) {
        localItems.add(items[i]);
      } else {
        apiItems.add(items[i]);
      }
    }
    
    debugPrint('🔄 Traducción: ${localItems.length} locales (skip) + ${apiItems.length} API (traducir)');
    
    // Traducir solo items de API que tengan nombres en inglés
    List<FoodItem> translatedApiItems = apiItems;
    if (apiItems.isNotEmpty) {
      final titlesToTranslate = apiItems.map((e) => e.nameEn ?? e.nameEs).toList();
      
      try {
        final processedTexts = await translationService.translateAndDescribeBatch(
          titles: titlesToTranslate,
          source: 'inglés',
          target: 'español',
        );
        
        translatedApiItems = [];
        for (int i = 0; i < apiItems.length; i++) {
          final item = apiItems[i];
          String nameEs = item.nameEs;
          String shortDescEs = _generateFallbackDescription(item);

          if (i < processedTexts.length && processedTexts[i].isNotEmpty) {
            final parts = processedTexts[i].split('|');
            final translated = parts[0].trim();
            // Solo usar la traducción si no está vacía y no es idéntica al inglés
            if (translated.isNotEmpty) {
              nameEs = _capitalizeFirst(translated);
            }
            if (parts.length > 1 && parts[1].trim().isNotEmpty) {
              shortDescEs = parts[1].trim();
            }
          }

          final newMetadata = Map<String, dynamic>.from(item.metadata);
          if (!newMetadata.containsKey('short_description_es') || 
              (newMetadata['short_description_es'] as String?)?.isEmpty != false) {
            newMetadata['short_description_es'] = shortDescEs;
          }

          translatedApiItems.add(
            item.copyWith(
              nameEs: nameEs,
              metadata: newMetadata,
            ),
          );
        }
      } catch (e) {
        debugPrint('⚠️ Error al traducir API items: $e — usando nombres originales');
        // En caso de error, crear nombres legibles en español para items con nombre en inglés
        translatedApiItems = apiItems.map((item) {
          final newMetadata = Map<String, dynamic>.from(item.metadata);
          if (!newMetadata.containsKey('short_description_es')) {
            newMetadata['short_description_es'] = _generateFallbackDescription(item);
          }
          return item.copyWith(
            nameEs: _capitalizeFirst(item.nameEs),
            metadata: newMetadata,
          );
        }).toList();
      }
    }
    
    // Combinar: locales primero (ya tienen imágenes y descripciones), luego API
    return [...localItems, ...translatedApiItems];
  }
  
  /// Genera una descripción de fallback basada en los macros del alimento
  String _generateFallbackDescription(FoodItem item) {
    final kcal = item.nutrition.kcal;
    final protein = item.nutrition.proteinG;
    
    if (protein > 20) return 'Opción alta en proteínas, ideal para tu día.';
    if (kcal < 100) return 'Opción ligera y baja en calorías.';
    if (kcal > 400) return 'Plato contundente y energético.';
    return 'Una opción nutritiva y equilibrada para tu registro.';
  }
  
  /// Capitaliza la primera letra de cada palabra
  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.length <= 2 && ['de', 'la', 'el', 'y', 'a', 'en', 'al', 'con'].contains(word.toLowerCase())) {
        return word.toLowerCase();
      }
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  /// Limpia la caché en memoria de resultados completos
  void clearFullItemCache() {
    _fullItemCache.clear();
    debugPrint('🗑️ Caché de items completos limpiada');
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
