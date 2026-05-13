import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/food_provider.dart';
import '../services/network_policy.dart';

class SpoonacularProvider implements RecipeProvider {
  final http.Client _client;
  final String _apiKey;
  final String _baseUrl;
  final Duration _timeout;

  SpoonacularProvider({
    required String apiKey,
    http.Client? client,
    String baseUrl = 'https://api.spoonacular.com',
    Duration timeout = const Duration(seconds: 5),
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey,
        _baseUrl = baseUrl,
        _timeout = timeout;

  @override
  Future<List<FoodItem>> searchRecipes(String ingredientEn) async {
    if (_apiKey.isEmpty) {
      return <FoodItem>[];
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl/recipes/complexSearch?apiKey=$_apiKey&query=$ingredientEn&number=10&addRecipeNutrition=true&addRecipeInformation=true',
      );

      final response = await runWithRetry(
        operation: () => _client.get(uri).timeout(_timeout),
      );
      if (response.statusCode != 200) {
        return <FoodItem>[];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (json['results'] as List?) ?? const [];

      return results
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .map(_mapRecipe)
          .toList();
    } catch (_) {
      return <FoodItem>[];
    }
  }

  FoodItem _mapRecipe(Map<String, dynamic> row) {
    final nutrition =
        (row['nutrition'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    final nutrients =
        (nutrition['nutrients'] as List?)?.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() ??
            <Map<String, dynamic>>[];

    final kcal = _findNutrient(nutrients, const {'Calories'}) ?? 0;
    final protein = _findNutrient(nutrients, const {'Protein'}) ?? 0;
    final carbs = _findNutrient(nutrients, const {'Carbohydrates'}) ?? 0;
    final fat = _findNutrient(nutrients, const {'Fat'}) ?? 0;

    return FoodItem(
      source: FoodSource.spoonacular,
      itemId: row['id']?.toString() ?? 'recipe_item',
      nameEs: row['title']?.toString() ?? 'Receta',
      nameEn: row['title']?.toString(),
      portion: const Portion(amount: 1, unit: 'unidad'),
      nutrition: Nutrition(
        kcal: kcal,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      ),
      imageUrl: row['image']?.toString(),
      metadata: {
        'provider_raw_id': row['id']?.toString(),
        'summary': row['summary']?.toString(),
        'instructions': row['instructions']?.toString(),
      },
    );
  }

  double? _findNutrient(List<Map<String, dynamic>> nutrients, Set<String> names) {
    for (final n in nutrients) {
      final name = n['name']?.toString();
      if (name == null || !names.contains(name)) {
        continue;
      }
      final value = n['amount'];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }
}
