import 'package:flutter/foundation.dart';

/// Servicio de búsqueda inteligente para recetas
/// Expande búsquedas con sinónimos y categorías en español
class SmartRecipeSearchService {
  // Mapeo de términos comunes a ingredientes base
  static const Map<String, List<String>> _categoryMap = {
    // Desayunos
    'desayuno': ['huevo', 'pan', 'café', 'leche', 'queso', 'jamón'],
    'desayuno chileno': ['huevo', 'pan', 'poroto', 'tomate', 'cebolla', 'avocado'],
    'breakfast': ['huevo', 'pan', 'café', 'leche', 'queso', 'jamón'],
    
    // Almuerzos
    'almuerzo': ['carne', 'pollo', 'arroz', 'verdura', 'ensalada'],
    'almuerzo chileno': ['carne', 'pollo', 'arroz', 'poroto', 'ensalada chilena'],
    'lunch': ['carne', 'pollo', 'arroz', 'verdura', 'ensalada'],
    
    // Cenas
    'cena': ['pescado', 'pollo', 'ensalada', 'verdura', 'sopa'],
    'cena chilena': ['cazuela', 'pastel choclo', 'empanada', 'charquicán'],
    'dinner': ['pescado', 'pollo', 'ensalada', 'verdura', 'sopa'],
    
    // Once (merienda chilena)
    'once': ['pan', 'queso', 'jamón', 'tomate', 'té', 'café'],
    'once chilena': ['pan', 'queso', 'jamón', 'palta', 'tomate', 'té'],
    
    // Snacks
    'snack': ['yogurt', 'fruta', 'frutos secos', 'galleta', 'chocolate'],
    'merienda': ['pan', 'fruta', 'yogurt', 'chocolate'],
  };

  // Sinónimos comunes
  static const Map<String, List<String>> _synonyms = {
    'pollo': ['pechuga', 'ala', 'muslo', 'chicken', 'ave'],
    'carne': ['res', 'beef', 'filete', 'asado', 'bistec'],
    'pescado': ['salmón', 'trucha', 'caballa', 'jurel', 'congrio', 'fish'],
    'pan': ['pan blanco', 'pan integral', 'bread'],
    'arroz': ['rice', 'risotto'],
    'papas': ['papa', 'potato', 'patatas', 'papas fritas'],
    'manzana': ['apple', 'manzanas'],
    'fruta': ['frutas', 'plátano', 'naranja', 'uva', 'fresa', 'cherry'],
    'verdura': ['verduras', 'brócoli', 'zanahoria', 'espinaca', 'lechuga'],
    'huevo': ['huevos', 'egg', 'eggs'],
    'leche': ['lácteos', 'queso', 'yogurt', 'milk'],
  };

  /// Expande una búsqueda en español en múltiples términos de búsqueda
  /// Retorna lista de términos para buscar secuencialmente
  static List<String> expandSearchTerms(String userQuery) {
    final normalized = userQuery.toLowerCase().trim();
    final terms = <String>{};

    // 1. Agregar el término original
    terms.add(normalized);

    // 2. Si es una categoría conocida, agregar sus ingredientes
    if (_categoryMap.containsKey(normalized)) {
      final ingredients = _categoryMap[normalized]!;
      terms.addAll(ingredients);
      debugPrint('🔍 Expandido ($normalized): ${ingredients.take(3).join(", ")}...');
      return terms.toList();
    }

    // 3. Buscar si el término contiene una categoría (Ej: "desayuno chileno")
    for (final category in _categoryMap.keys) {
      if (normalized.contains(category) && category.length > 3) {
        final ingredients = _categoryMap[category]!;
        terms.addAll(ingredients);
        debugPrint('🔍 Encontrada categoría en query ($category): ${ingredients.take(3).join(", ")}...');
        break;
      }
    }

    // 4. Agregar sinónimos del término principal
    if (_synonyms.containsKey(normalized)) {
      terms.addAll(_synonyms[normalized]!);
      debugPrint('🔍 Sinónimos encontrados: ${_synonyms[normalized]!.take(3).join(", ")}...');
    }

    // 5. Buscar sinónimos en palabras clave del query
    for (final word in normalized.split(' ')) {
      if (_synonyms.containsKey(word)) {
        terms.addAll(_synonyms[word]!.take(2)); // Limitar para no explotar
      }
    }

    return terms.toList();
  }

  /// Obtiene ingredientes base para una categoría de comida
  static List<String> getBaseIngredientsForMealSlot(String mealSlot) {
    final lower = mealSlot.toLowerCase();
    if (_categoryMap.containsKey(lower)) {
      return _categoryMap[lower]!;
    }
    return const [];
  }

  /// Verifica si un término es una categoría conocida
  static bool isKnownCategory(String term) {
    return _categoryMap.containsKey(term.toLowerCase());
  }
}
