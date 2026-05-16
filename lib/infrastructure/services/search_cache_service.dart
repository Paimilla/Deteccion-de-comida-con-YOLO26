import 'package:flutter/foundation.dart';

/// Servicio de caché para búsquedas de recetas y traducciones
/// Reduce llamadas a API y mejora latencia
class SearchCacheService {
  final Map<String, List<String>> _translationCache = {};
  final Map<String, List<String>> _recipeSearchCache = {};
  final Map<String, List<String>> _descriptionCache = {};
  
  // TTL en minutos (0 = sin expiración)
  static const int _cacheTtlMinutes = 60;

  /// Obtiene traducción cacheada o null si no existe
  String? getTranslation(String key) => _translationCache[key]?.first;

  /// Guarda traducción en caché
  void setTranslation(String key, String value) {
    _translationCache[key] = [value, DateTime.now().toString()];
    debugPrint('✅ Caché: Traducción guardada para "$key"');
  }

  /// Obtiene búsqueda de recetas cacheada o null
  List<String>? getRecipeSearch(String query) {
    final cached = _recipeSearchCache[query];
    if (cached != null && _isValid(cached)) {
      debugPrint('✅ Caché HIT: Búsqueda "$query"');
      return cached.sublist(0, cached.length - 1).cast<String>();
    }
    return null;
  }

  /// Guarda resultados de búsqueda de recetas
  void setRecipeSearch(String query, List<String> results) {
    _recipeSearchCache[query] = [...results, DateTime.now().toString()];
    debugPrint('✅ Caché: ${results.length} resultados guardados para "$query"');
  }

  /// Obtiene descripciones cacheadas
  List<String>? getDescriptions(String key) {
    final cached = _descriptionCache[key];
    if (cached != null && _isValid(cached)) {
      return cached.sublist(0, cached.length - 1).cast<String>();
    }
    return null;
  }

  /// Guarda descripciones generadas
  void setDescriptions(String key, List<String> descriptions) {
    _descriptionCache[key] = [...descriptions, DateTime.now().toString()];
    debugPrint('✅ Caché: ${descriptions.length} descripciones guardadas');
  }

  /// Verifica si entrada en caché es válida (no expirada)
  bool _isValid(List<String> cached) {
    if (cached.isEmpty) return false;
    if (_cacheTtlMinutes == 0) return true; // Sin expiración
    
    try {
      final timestamp = DateTime.parse(cached.last);
      final now = DateTime.now();
      return now.difference(timestamp).inMinutes < _cacheTtlMinutes;
    } catch (_) {
      return true;
    }
  }

  /// Limpia todo el caché
  void clearAll() {
    _translationCache.clear();
    _recipeSearchCache.clear();
    _descriptionCache.clear();
    debugPrint('🗑️  Caché limpiado');
  }

  /// Obtiene estadísticas del caché
  Map<String, int> getStats() => {
    'translations': _translationCache.length,
    'searches': _recipeSearchCache.length,
    'descriptions': _descriptionCache.length,
  };
}
