import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models/tracking_models.dart';
import '../infrastructure/repositories/json_tracking_repository.dart';
import '../infrastructure/services/api_config.dart';
import '../infrastructure/services/auth_service.dart';
import '../infrastructure/services/gemini_nlp_service.dart';
import '../infrastructure/services/registration_tracker.dart';
import 'app_services.dart';
import 'bootstrap_example.dart';
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
          const String.fromEnvironment('SPOONACULAR_API_KEY', defaultValue: ''),
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
          const String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''),
      edamamAppId:
          const String.fromEnvironment('EDAMAM_APP_ID', defaultValue: ''),
      edamamAppKey:
          const String.fromEnvironment('EDAMAM_APP_KEY', defaultValue: ''),
    );

    final chileDatasetJson = await _loadChileDatasetJson();
    final orchestrator = await BootstrapExample.build(
      config: config,
      chileDatasetJson: chileDatasetJson,
    );

    final storagePath = '${Directory.systemTemp.path}/nutrifoto_tracking.json';
    final trackingRepository = JsonTrackingRepository(filePath: storagePath);

    const defaultGoals = NutritionGoals(
      kcal: 2200,
      proteinG: 130,
      carbsG: 260,
      fatG: 70,
    );

    // Inicializar servicio de NLP con Gemini
    final geminiNlpService = GeminiNlpService(
      apiKey: config.geminiApiKey,
    );

    // Inicializar servicio de autenticación y restaurar sesión
    final authService = AuthService();
    await authService.initialize();

    // Tracker de registros (webhook configurable)
    final registrationTracker = RegistrationTracker(
      webhookUrl: const String.fromEnvironment(
        'REGISTRATION_WEBHOOK_URL',
        defaultValue: '',
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
    );
  }

  static Future<String> _loadChileDatasetJson() async {
    return rootBundle.loadString('assets/data/chile_food_44.sample.json');
  }
}
