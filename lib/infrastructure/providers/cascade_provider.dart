import 'package:flutter/foundation.dart';

import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/food_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CascadeSearchProvider — Busca alimentos en múltiples fuentes
// ═══════════════════════════════════════════════════════════════════════════════
// Intenta cada proveedor en orden. Si el primero devuelve resultados, retorna.
// Si falla o está vacío, sigue con el siguiente. Combina resultados si se desea.
// ═══════════════════════════════════════════════════════════════════════════════

class CascadeSearchProvider implements FoodSearchProvider {
  final List<FoodSearchProvider> _providers;

  CascadeSearchProvider(this._providers);

  @override
  Future<List<FoodItem>> searchFood(String textEn) async {
    final allResults = <FoodItem>[];
    final seenIds = <String>{};

    for (final provider in _providers) {
      try {
        final results = await provider.searchFood(textEn);

        for (final item in results) {
          // Evitar duplicados por nombre normalizado
          final key = item.nameEs.toLowerCase().trim();
          if (!seenIds.contains(key)) {
            seenIds.add(key);
            allResults.add(item);
          }
        }

        // Si ya tenemos suficientes resultados, parar
        if (allResults.length >= 8) break;
      } catch (e) {
        debugPrint('⚠️ CascadeSearch: Error en ${provider.runtimeType}: $e');
        // Continuar con el siguiente proveedor
      }
    }

    debugPrint('🔍 CascadeSearch: ${allResults.length} resultado(s) totales');
    return allResults;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CascadeRecipeProvider — Busca recetas en múltiples fuentes
// ═══════════════════════════════════════════════════════════════════════════════

class CascadeRecipeProvider implements RecipeProvider {
  final List<RecipeProvider> _providers;

  CascadeRecipeProvider(this._providers);

  @override
  Future<List<FoodItem>> searchRecipes(String ingredientEn) async {
    for (final provider in _providers) {
      try {
        final results = await provider.searchRecipes(ingredientEn);
        if (results.isNotEmpty) {
          debugPrint('🍳 CascadeRecipe: ${results.length} resultado(s) de ${provider.runtimeType}');
          return results;
        }
      } catch (e) {
        debugPrint('⚠️ CascadeRecipe: Error en ${provider.runtimeType}: $e');
      }
    }
    return const [];
  }
}
