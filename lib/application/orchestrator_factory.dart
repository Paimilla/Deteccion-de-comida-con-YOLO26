import '../domain/repositories/food_provider.dart';
import '../infrastructure/providers/cascade_provider.dart';
import '../infrastructure/providers/edamam_provider.dart';
import '../infrastructure/providers/edamam_recipe_provider.dart';
import '../infrastructure/providers/onnx_vision_provider.dart';
import '../infrastructure/providers/local_chile_provider.dart';
import '../infrastructure/providers/openfoodfacts_provider.dart';
import '../infrastructure/providers/openfoodfacts_search_provider.dart';
import '../infrastructure/providers/spoonacular_provider.dart';
import '../infrastructure/providers/usda_provider.dart';
import '../infrastructure/services/api_config.dart';
import '../infrastructure/services/gemini_nlp_service.dart';
import '../infrastructure/services/gemini_translation_service.dart';
import 'food_orchestrator.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// OrchestratorFactory — Instancia el FoodOrchestrator con todos los proveedores
// ═══════════════════════════════════════════════════════════════════════════════
// Prioridad de búsqueda de alimentos:
//   1. Edamam (si tiene keys válidas) — base de datos nutricional profesional
//   2. OpenFoodFacts Search — GRATIS, sin key, soporta español
//   3. USDA (si tiene key) — base de datos gubernamental de EE.UU.
//
// Prioridad de recetas:
//   1. Edamam Food DB (si tiene keys) — búsqueda por ingrediente
//   2. OpenFoodFacts Search — fallback gratuito
//   3. Spoonacular (si tiene key) — alternativa
//
// Barcode: OpenFoodFacts (siempre gratis)
// ═══════════════════════════════════════════════════════════════════════════════

class OrchestratorFactory {
  static Future<FoodOrchestrator> create({
    required ApiConfig config,
    required Map<String, dynamic> chileDataset,
  }) async {
    // Crear provider de ONNX SIN inicializar (lazy loading)
    final visionProvider = OnnxVisionProvider();

    // ── Proveedor gratuito (siempre disponible) ──
    final offSearch = OpenFoodFactsSearchProvider(
      baseUrl: config.openFoodFactsBaseUrl,
    );

    // ── Proveedores de búsqueda de alimentos ──
    final searchProviders = <FoodSearchProvider>[];

    // Edamam: proveedor premium
    if (config.edamamAppId.isNotEmpty && config.edamamAppKey.isNotEmpty) {
      searchProviders.add(EdamamProvider(
        appId: config.edamamAppId,
        appKey: config.edamamAppKey,
      ));
    }

    // OpenFoodFacts: siempre disponible como fallback
    searchProviders.add(offSearch);

    // USDA: si tiene key
    if (config.usdaApiKey.isNotEmpty) {
      searchProviders.add(UsdaProvider(
        apiKey: config.usdaApiKey,
        baseUrl: config.usdaBaseUrl,
      ));
    }

    final cascadeSearch = CascadeSearchProvider(searchProviders);

    // ── Proveedores de recetas ──
    final recipeProviders = <RecipeProvider>[];

    // 1. Spoonacular: la mejor calidad visual (fotos reales)
    if (config.spoonacularApiKey.isNotEmpty) {
      recipeProviders.add(SpoonacularProvider(
        apiKey: config.spoonacularApiKey,
        baseUrl: config.spoonacularBaseUrl,
      ));
    }

    // 2. Edamam: excelente precisión nutricional
    if (config.edamamAppId.isNotEmpty && config.edamamAppKey.isNotEmpty) {
      recipeProviders.add(EdamamRecipeProvider(
        appId: config.edamamAppId,
        appKey: config.edamamAppKey,
      ));
    }

    // 3. OpenFoodFacts: fallback gratuito
    recipeProviders.add(offSearch);

    final cascadeRecipes = CascadeRecipeProvider(recipeProviders);

    // ── Servicio de Traducción (Gemini como prioridad) ──
    final geminiNlp = GeminiNlpService(
      apiKey: config.geminiApiKey,
      groqApiKey: config.groqApiKey,
    );
    final TranslationService translationService;
    
    if (config.geminiApiKey.isNotEmpty) {
      translationService = GeminiTranslationService(geminiNlp);
    } else {
      // Si no hay key, usamos un fallback básico (podría ser un servicio dummy o tirar error)
      translationService = GeminiTranslationService(geminiNlp); 
    }

    return FoodOrchestrator(
      localChileProvider: LocalChileProvider(chileDataset),
      barcodeProvider:
          OpenFoodFactsProvider(baseUrl: config.openFoodFactsBaseUrl),
      usdaProvider: cascadeSearch,
      recipeProvider: cascadeRecipes,
      translationService: translationService,
      visionProvider: visionProvider,
    );
  }
}
