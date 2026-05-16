import '../../../domain/models/tracking_models.dart';

/// Servicio de sugerencias inteligentes por tipo de comida
/// Adapta búsquedas según la hora del día y preferencias del usuario
class MealSlotSuggestionsService {
  // Sugerencias por tipo de comida en español (mucho mejor que el inglés)
  static const Map<MealSlot, List<String>> _spanishSuggestions = {
    MealSlot.desayuno: [
      'desayuno chileno',
      'huevos fritos',
      'pan tostado',
      'café con leche',
      'pan con queso',
      'avena',
      'yogurt',
      'fruta fresca',
    ],
    MealSlot.almuerzo: [
      'almuerzo chileno',
      'pollo a la plancha',
      'arroz con carne',
      'cazuela',
      'ensalada chilena',
      'charquicán',
      'filete',
      'pastel de choclo',
    ],
    MealSlot.cena: [
      'cena saludable',
      'pescado a la plancha',
      'salmón',
      'verduras salteadas',
      'pechuga de pollo',
      'sopa',
      'cazuela',
      'ensalada mixta',
    ],
    MealSlot.once: [
      'once chilena saludable',
      'pan con palta y huevo',
      'té con sándwich de pavo',
      'quesillo con tomate',
      'tostadas integrales',
      'huevos revueltos',
      'once nutritiva chilena',
      'sándwich de atún',
    ],
    MealSlot.snack: [
      'snack saludable chileno',
      'frutos secos',
      'barrita de cereal casera',
      'hummus con verduras',
      'manzana con mantequilla de maní',
      'yogurt con avena',
      'mix de semillas',
      'huevo duro',
    ],
  };

  // Sugerencias rápidas (para chips)
  static const Map<MealSlot, List<String>> _quickSuggestions = {
    MealSlot.desayuno: [
      '🥚 Huevo',
      '🍞 Pan',
      '🥛 Leche',
      '🍌 Fruta',
      '🧈 Palta',
      '☕ Café',
    ],
    MealSlot.almuerzo: [
      '🍗 Pollo',
      '🍚 Arroz',
      '🥗 Ensalada',
      '🥩 Carne',
      '🍝 Pasta',
      '🥔 Papa',
    ],
    MealSlot.cena: [
      '🐟 Pescado',
      '🥬 Verduras',
      '🍗 Pollo',
      '🥗 Ensalada',
      '🍲 Sopa',
      '🧅 Cebollas',
    ],
    MealSlot.once: [
      '🥪 Sándwich',
      '🧀 Quesillo',
      '🥑 Palta',
      '🥚 Huevo',
      '🍅 Tomate',
      '☕ Té',
    ],
    MealSlot.snack: [
      '🍎 Fruta',
      '🥜 Frutos secos',
      '🧘 Yogurt',
      '🥕 Hummus',
      '🍪 Galletas',
      '🥛 Proteína',
    ],
  };

  /// Obtiene sugerencias completas para un tipo de comida
  static List<String> getSuggestionsForMealSlot(MealSlot mealSlot) {
    return _spanishSuggestions[mealSlot] ?? _spanishSuggestions[MealSlot.almuerzo]!;
  }

  /// Obtiene sugerencias rápidas (para mostrar en chips)
  static List<String> getQuickSuggestionsForMealSlot(MealSlot mealSlot) {
    return _quickSuggestions[mealSlot] ?? _quickSuggestions[MealSlot.almuerzo]!;
  }

  /// Obtiene la categoría de búsqueda para generar sugerencias iniciales
  static String getSearchQueryForMealSlot(MealSlot mealSlot) {
    switch (mealSlot) {
      case MealSlot.desayuno:
        return 'healthy breakfast eggs avocado fruit';
      case MealSlot.almuerzo:
        return 'healthy lunch chicken salmon salad';
      case MealSlot.cena:
        return 'healthy dinner soup grilled vegetables';
      case MealSlot.once:
        return 'afternoon tea sandwich healthy snack';
      case MealSlot.snack:
        return 'healthy fruit nuts yogurt snack';
    }
  }

  /// Obtiene descripción amigable del tipo de comida
  static String getDescriptionForMealSlot(MealSlot mealSlot) {
    switch (mealSlot) {
      case MealSlot.desayuno:
        return 'Opciones para empezar el día con energía';
      case MealSlot.almuerzo:
        return 'Comidas completas y nutritivas para el mediodía';
      case MealSlot.cena:
        return 'Cenas ligeras y saludables para terminar el día';
      case MealSlot.once:
        return 'Tradicional merienda chilena';
      case MealSlot.snack:
        return 'Opciones rápidas y nutritivas entre comidas';
    }
  }

  /// Obtiene un gradiente para el tipo de comida
  static Map<String, dynamic> getThemeForMealSlot(MealSlot mealSlot) {
    switch (mealSlot) {
      case MealSlot.desayuno:
        return {
          'emoji': '🌅',
          'color_primary': '#FFA726',
          'color_secondary': '#FF7043',
          'description': 'Desayuno',
        };
      case MealSlot.almuerzo:
        return {
          'emoji': '☀️',
          'color_primary': '#66BB6A',
          'color_secondary': '#43A047',
          'description': 'Almuerzo',
        };
      case MealSlot.cena:
        return {
          'emoji': '🌙',
          'color_primary': '#5C6BC0',
          'color_secondary': '#3F51B5',
          'description': 'Cena',
        };
      case MealSlot.once:
        return {
          'emoji': '☕',
          'color_primary': '#AB47BC',
          'color_secondary': '#8E24AA',
          'description': 'Once',
        };
      case MealSlot.snack:
        return {
          'emoji': '🍿',
          'color_primary': '#FF6E40',
          'color_secondary': '#D84315',
          'description': 'Snack',
        };
    }
  }

  /// Obtiene primer elemento de sugerencias (para buscar inicial)
  static String getInitialSearchForMealSlot(MealSlot mealSlot) {
    final suggestions = getSuggestionsForMealSlot(mealSlot);
    return suggestions.isNotEmpty ? suggestions.first : 'almuerzo';
  }

  /// Valida si debería mostrar sugerencias (no en resultados de búsqueda)
  static bool shouldShowSuggestions(
    bool hasSearchResults,
    bool isLoading,
    List<String> currentResults,
  ) {
    return !hasSearchResults && !isLoading && currentResults.isEmpty;
  }
}
