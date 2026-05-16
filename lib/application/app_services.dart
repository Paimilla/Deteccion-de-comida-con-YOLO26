import '../domain/models/tracking_models.dart';
import '../infrastructure/services/auth_service.dart';
import '../infrastructure/services/gemini_nlp_service.dart';
import '../infrastructure/services/registration_tracker.dart';
import '../infrastructure/services/search_cache_service.dart';
import 'food_orchestrator.dart';
import 'feature_flags.dart';
import 'usecases/history_usecases.dart';
import 'usecases/insights_usecases.dart';
import 'usecases/tracking_usecases.dart';

class AppServices {
  final FoodOrchestrator foodOrchestrator;
  final TrackingUseCases trackingUseCases;
  final HistoryUseCases historyUseCases;
  final InsightsUseCases insightsUseCases;
  final FeatureFlags featureFlags;
  final NutritionGoals defaultGoals;

  /// Servicio de NLP para parsear comandos de voz con Gemini
  final GeminiNlpService geminiNlpService;

  /// Servicio de autenticación (Google Sign-In + email)
  final AuthService authService;

  /// Tracker de registros (webhook a Google Sheets u otro destino)
  final RegistrationTracker registrationTracker;

  /// Servicio de caché de búsquedas y traducciones
  final SearchCacheService? searchCache;

  /// Alias corto para geminiNlpService
  GeminiNlpService get nlp => geminiNlpService;

  const AppServices({
    required this.foodOrchestrator,
    required this.trackingUseCases,
    required this.historyUseCases,
    required this.insightsUseCases,
    required this.featureFlags,
    required this.defaultGoals,
    required this.geminiNlpService,
    required this.authService,
    required this.registrationTracker,
    this.searchCache,
  });
}
