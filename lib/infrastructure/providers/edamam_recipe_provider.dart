import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/food_provider.dart';
import '../services/network_policy.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// EdamamRecipeProvider — Búsqueda de recetas vía Edamam Food Database API
// ═══════════════════════════════════════════════════════════════════════════════
// Usa el endpoint de Food Database (parser) que acepta las mismas keys.
// Busca alimentos/platos relacionados con un ingrediente y devuelve
// los que tienen datos nutricionales completos.
// ═══════════════════════════════════════════════════════════════════════════════

class EdamamRecipeProvider implements RecipeProvider {
  final String _appId;
  final String _appKey;
  final http.Client _client;
  final Duration _timeout;

  EdamamRecipeProvider({
    required String appId,
    required String appKey,
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  })  : _appId = appId,
        _appKey = appKey,
        _client = client ?? http.Client(),
        _timeout = timeout;

  @override
  Future<List<FoodItem>> searchRecipes(String ingredientEn) async {
    if (_appId.isEmpty || _appKey.isEmpty) {
      debugPrint('⚠️ EdamamRecipe: API keys vacías');
      return const [];
    }

    try {
      // Usar Food Database API (parser) — las mismas keys funcionan
      final uri = Uri.parse(
        'https://api.edamam.com/api/food-database/v2/parser'
        '?app_id=$_appId'
        '&app_key=$_appKey'
        '&ingr=${Uri.encodeComponent(ingredientEn)}'
        '&nutrition-type=cooking',
      );

      final response = await runWithRetry(
        operation: () => _client.get(uri).timeout(_timeout),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ EdamamRecipe: HTTP ${response.statusCode}');
        return const [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final hints = (json['hints'] as List?) ?? [];

      final results = <FoodItem>[];

      for (final hint in hints.take(10)) {
        if (hint is! Map) continue;
        final food = (hint['food'] as Map?)?.cast<String, dynamic>();
        if (food == null) continue;

        final nutrients =
            (food['nutrients'] as Map?)?.cast<String, dynamic>() ?? {};

        final kcal = _asDouble(nutrients['ENERC_KCAL']) ?? 0;
        final protein = _asDouble(nutrients['PROCNT']) ?? 0;
        final carbs = _asDouble(nutrients['CHOCDF']) ?? 0;
        final fat = _asDouble(nutrients['FAT']) ?? 0;

        // Solo incluir si tiene datos nutricionales
        if (kcal == 0 && protein == 0 && carbs == 0 && fat == 0) continue;

        final label = food['label']?.toString() ?? 'Alimento';
        final foodId =
            food['foodId']?.toString() ?? 'edamam_${label.hashCode}';
        final image = food['image']?.toString();
        final category = food['category']?.toString() ?? '';
        
        // Skip very generic/low-quality items (condiments, water, etc.)
        if (label.length < 3) continue;
        if (kcal < 10 && protein < 1) continue; // Water, salt, etc.

        results.add(FoodItem(
          source: FoodSource.edamam,
          itemId: foodId,
          nameEs: label, // Will be translated by orchestrator
          nameEn: label,
          portion: const Portion(amount: 100, unit: 'g'),
          nutrition: Nutrition(
            kcal: kcal,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
          ),
          imageUrl: image,
          metadata: {
            'provider': 'edamam',
            'category': category,
          },
        ));
      }

      debugPrint(
          '✅ EdamamRecipe: ${results.length} resultado(s) para "$ingredientEn"');
      return results;
    } catch (e) {
      debugPrint('❌ EdamamRecipe error: $e');
      return const [];
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
