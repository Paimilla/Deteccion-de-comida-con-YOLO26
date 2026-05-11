class ApiConfig {
  final String openFoodFactsBaseUrl;
  final String usdaApiKey;
  final String usdaBaseUrl;
  final String spoonacularApiKey;
  final String spoonacularBaseUrl;
  final String libreTranslateBaseUrl;
  final String? libreTranslateApiKey;
  final String fastApiBaseUrl;

  /// API key de Google Gemini para el parser NLP de voz
  final String geminiApiKey;

  /// Edamam Food Database API credentials
  final String edamamAppId;
  final String edamamAppKey;

  const ApiConfig({
    required this.openFoodFactsBaseUrl,
    required this.usdaApiKey,
    required this.usdaBaseUrl,
    required this.spoonacularApiKey,
    required this.spoonacularBaseUrl,
    required this.libreTranslateBaseUrl,
    required this.fastApiBaseUrl,
    this.libreTranslateApiKey,
    this.geminiApiKey = '',
    this.edamamAppId = '',
    this.edamamAppKey = '',
  });
}
