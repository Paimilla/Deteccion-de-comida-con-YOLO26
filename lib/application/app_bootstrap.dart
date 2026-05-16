import 'dart:io' show Directory, File;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/repositories/tracking_repository.dart';
import '../infrastructure/repositories/shared_prefs_tracking_repository.dart';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models/tracking_models.dart';
import '../infrastructure/repositories/json_tracking_repository.dart';
import '../infrastructure/services/api_config.dart';
import '../infrastructure/services/auth_service.dart';
import '../infrastructure/services/gemini_nlp_service.dart';
import '../infrastructure/services/registration_tracker.dart';
import 'app_services.dart';
import 'orchestrator_builder.dart';
import 'feature_flags.dart';
import 'usecases/history_usecases.dart';
import 'usecases/insights_usecases.dart';
import 'usecases/tracking_usecases.dart';

class AppBootstrap {
  static Future<AppServices> initialize() async {
    final config = ApiConfig(
      openFoodFactsBaseUrl: const String.fromEnvironment(
        'OPENFOODFACTS_BASE_URL',
        defaultValue: 'https://world.openfoodfacts.org',
      ),
      usdaApiKey: const String.fromEnvironment('USDA_API_KEY', defaultValue: ''),
      usdaBaseUrl: const String.fromEnvironment(
        'USDA_BASE_URL',
        defaultValue: 'https://api.nal.usda.gov/fdc/v1',
      ),
      spoonacularApiKey:
          const String.fromEnvironment('SPOONACULAR_API_KEY', defaultValue: '2c69078f5d8c4eecafbb21e3a617fc71'),
      spoonacularBaseUrl: const String.fromEnvironment(
        'SPOONACULAR_BASE_URL',
        defaultValue: 'https://api.spoonacular.com',
      ),
      libreTranslateBaseUrl: const String.fromEnvironment(
        'LIBRETRANSLATE_BASE_URL',
        defaultValue: 'https://libretranslate.com',
      ),
      libreTranslateApiKey:
          const String.fromEnvironment('LIBRETRANSLATE_API_KEY', defaultValue: ''),
      fastApiBaseUrl: const String.fromEnvironment(
        'FASTAPI_BASE_URL',
        defaultValue: 'http://10.0.2.2:8000',
      ),
      geminiApiKey:
          const String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSyDfzEiD7bPjGhDDtVXthv5wD1L3PWUT0Zs'),
      groqApiKey:
          const String.fromEnvironment('GROQ_API_KEY', defaultValue: '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'),
      edamamAppId:
          const String.fromEnvironment('EDAMAM_APP_ID', defaultValue: '4141d0d4'),
      edamamAppKey:
          const String.fromEnvironment('EDAMAM_APP_KEY', defaultValue: 'a79c06be7a90459dc28ed9ccf5ccc837'),
    );

    final chileDatasetJson = await _loadChileDatasetJson();
    final orchestrator = await OrchestratorBuilder.build(
      config: config,
      chileDatasetJson: chileDatasetJson,
    );

    final prefs = await SharedPreferences.getInstance();
    final TrackingRepository trackingRepository;

    if (kIsWeb) {
      trackingRepository = SharedPrefsTrackingRepository(prefs);
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      final storagePath = '${docsDir.path}/nutrifoto_tracking.json';
      
      // Intentar migrar datos desde temp si existen (opcional pero amable)
      final tempFile = File('${Directory.systemTemp.path}/nutrifoto_tracking.json');
      final persistentFile = File(storagePath);
      
      bool shouldMigrate = await tempFile.exists() && 
          (!await persistentFile.exists() || (await persistentFile.length() < 5));

      if (shouldMigrate) {
        debugPrint('📦 Migrando datos desde carpeta temporal...');
        await tempFile.copy(storagePath);
      }
      
      trackingRepository = JsonTrackingRepository(filePath: storagePath);
    }

    const defaultGoals = NutritionGoals(
      kcal: 2200,
      proteinG: 130,
      carbsG: 260,
      fatG: 70,
    );

    // Inicializar servicio de NLP con Gemini
    final geminiNlpService = GeminiNlpService(
      apiKey: config.geminiApiKey,
      groqApiKey: config.groqApiKey,
    );

    // Inicializar servicio de autenticación y restaurar sesión
    final authService = AuthService();
    await authService.initialize();

    // Tracker de registros (webhook configurable)
    final registrationTracker = RegistrationTracker(
      webhookUrl: const String.fromEnvironment(
        'REGISTRATION_WEBHOOK_URL',
        defaultValue: 'https://script.google.com/macros/s/AKfycbwmkmfrAZSI18TWJdxxoy3cDp3P2QnZDQ71m1p-q1U5YxEc9VtxVQUDT95eOJqhblcI/exec',
      ),
    );

    return AppServices(
      foodOrchestrator: orchestrator,
      trackingUseCases: TrackingUseCases(trackingRepository),
      historyUseCases: HistoryUseCases(trackingRepository),
      insightsUseCases: InsightsUseCases(),
      featureFlags: const FeatureFlags(),
      defaultGoals: defaultGoals,
      geminiNlpService: geminiNlpService,
      authService: authService,
      registrationTracker: registrationTracker,
      searchCache: orchestrator.searchCache,
    );
  }

  static Future<String> _loadChileDatasetJson() async {
    return rootBundle.loadString('assets/data/chile_food_44.sample.json');
  }
}
