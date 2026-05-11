import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/food_provider.dart';
import '../services/network_policy.dart';

class UsdaProvider implements FoodSearchProvider {
  final http.Client _client;
  final String _apiKey;
  final String _baseUrl;
  final Duration _timeout;

  UsdaProvider({
    required String apiKey,
    http.Client? client,
    String baseUrl = 'https://api.nal.usda.gov/fdc/v1',
    Duration timeout = const Duration(seconds: 5),
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey,
        _baseUrl = baseUrl,
        _timeout = timeout;

  @override
  Future<List<FoodItem>> searchFood(String textEn) async {
    if (_apiKey.isEmpty) {
      return <FoodItem>[];
    }

    try {
      final uri = Uri.parse('$_baseUrl/foods/search?api_key=$_apiKey');
      final response = await runWithRetry(
        operation: () => _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'query': textEn, 'pageSize': 10}),
            )
            .timeout(_timeout),
      );

      if (response.statusCode != 200) {
        return <FoodItem>[];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final foods = (json['foods'] as List?) ?? const [];

      return foods
          .whereType<Map>()
          .map((row) => row.cast<String, dynamic>())
          .map(_mapFood)
          .toList();
    } catch (_) {
      return <FoodItem>[];
    }
  }

  FoodItem _mapFood(Map<String, dynamic> row) {
    final nutrients =
        (row['foodNutrients'] as List?)?.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList() ??
            <Map<String, dynamic>>[];

    final kcal = _findNutrient(nutrients, const {'Energy'}) ?? 0;
    final protein = _findNutrient(nutrients, const {'Protein'}) ?? 0;
    final carbs = _findNutrient(
          nutrients,
          const {'Carbohydrate, by difference', 'Carbohydrate'},
        ) ??
        0;
    final fat = _findNutrient(nutrients, const {'Total lipid (fat)', 'Fat'}) ?? 0;

    return FoodItem(
      source: FoodSource.usda,
      itemId: row['fdcId']?.toString() ?? row['description']?.toString() ?? 'usda_item',
      nameEs: row['description']?.toString() ?? 'Alimento USDA',
      nameEn: row['description']?.toString(),
      portion: const Portion(amount: 100, unit: 'g'),
      nutrition: Nutrition(
        kcal: kcal,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      ),
      metadata: {
        'provider_raw_id': row['fdcId']?.toString(),
        'dataType': row['dataType']?.toString(),
      },
    );
  }

  double? _findNutrient(List<Map<String, dynamic>> nutrients, Set<String> names) {
    for (final n in nutrients) {
      final name = n['nutrientName']?.toString();
      if (name == null || !names.contains(name)) {
        continue;
      }
      final value = n['value'];
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
