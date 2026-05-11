import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/food_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// OpenFoodFactsSearchProvider — Búsqueda de alimentos vía OpenFoodFacts
// ═══════════════════════════════════════════════════════════════════════════════
// API gratuita, sin key requerida. Soporta búsqueda en español.
// Endpoint: https://world.openfoodfacts.org/cgi/search.pl?search_terms=...
// ═══════════════════════════════════════════════════════════════════════════════

class OpenFoodFactsSearchProvider implements FoodSearchProvider, RecipeProvider {
  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  OpenFoodFactsSearchProvider({
    http.Client? client,
    String baseUrl = 'https://world.openfoodfacts.org',
    Duration timeout = const Duration(seconds: 8),
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _timeout = timeout;

  @override
  Future<List<FoodItem>> searchFood(String query) async {
    return _search(query);
  }

  @override
  Future<List<FoodItem>> searchRecipes(String ingredientEn) async {
    return _search(ingredientEn);
  }

  Future<List<FoodItem>> _search(String query) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query)}'
        '&search_simple=1'
        '&action=process'
        '&json=1'
        '&page_size=12'
        '&fields=product_name,nutriments,image_url,code,brands',
      );

      final response = await _client.get(
        uri,
        headers: {'User-Agent': 'NutrifotoAI/1.0 (nutrifoto@app.com)'},
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('❌ OpenFoodFacts Search: HTTP ${response.statusCode}');
        return const [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final products = (json['products'] as List?) ?? [];

      final results = <FoodItem>[];

      for (final product in products) {
        if (product is! Map) continue;
        final p = product.cast<String, dynamic>();

        final name = p['product_name']?.toString();
        if (name == null || name.isEmpty) continue;

        final nutrients = (p['nutriments'] as Map?)?.cast<String, dynamic>() ?? {};
        final brand = p['brands']?.toString();

        final kcal = _asDouble(nutrients['energy-kcal_100g']) ?? 0;
        final protein = _asDouble(nutrients['proteins_100g']) ?? 0;
        final carbs = _asDouble(nutrients['carbohydrates_100g']) ?? 0;
        final fat = _asDouble(nutrients['fat_100g']) ?? 0;

        // Solo incluir si tiene al menos calorías
        if (kcal == 0) continue;

        final displayName = brand != null && brand.isNotEmpty
            ? '$name ($brand)'
            : name;

        results.add(FoodItem(
          source: FoodSource.openFoodFacts,
          itemId: p['code']?.toString() ?? 'off_${name.hashCode}',
          nameEs: displayName,
          nameEn: displayName,
          portion: const Portion(amount: 100, unit: 'g'),
          nutrition: Nutrition(
            kcal: kcal,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
          ),
          imageUrl: p['image_url']?.toString(),
          metadata: {'provider': 'openfoodfacts'},
        ));
      }

      debugPrint('✅ OpenFoodFacts Search: ${results.length} resultado(s) para "$query"');
      return results;
    } catch (e) {
      debugPrint('❌ OpenFoodFacts Search error: $e');
      return const [];
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
