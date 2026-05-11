import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/food_provider.dart';
import '../services/network_policy.dart';

class OpenFoodFactsProvider implements BarcodeProvider {
  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  OpenFoodFactsProvider({
    http.Client? client,
    String baseUrl = 'https://world.openfoodfacts.org',
    Duration timeout = const Duration(seconds: 5),
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _timeout = timeout;

  @override
  Future<FoodItem?> findByBarcode(String barcode) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v2/product/$barcode');
      final response = await runWithRetry(
        operation: () => _client.get(uri).timeout(_timeout),
      );
      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if ((json['status'] as num?)?.toInt() != 1) {
        return null;
      }

      final product = (json['product'] as Map?)?.cast<String, dynamic>();
      if (product == null) {
        return null;
      }

      final nutriments =
          (product['nutriments'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

      final kcal = _asDouble(nutriments['energy-kcal_100g']) ??
          _asDouble(nutriments['energy-kcal']) ??
          0;
      final protein = _asDouble(nutriments['proteins_100g']) ?? 0;
      final carbs = _asDouble(nutriments['carbohydrates_100g']) ?? 0;
      final fat = _asDouble(nutriments['fat_100g']) ?? 0;

      final nameEs = (product['product_name_es'] ??
              product['product_name'] ??
              product['product_name_en'] ??
              'Producto escaneado')
          .toString();

      final image = product['image_url']?.toString();
      final brand = product['brands']?.toString();

      return FoodItem(
        source: FoodSource.openFoodFacts,
        itemId: product['_id']?.toString() ?? barcode,
        nameEs: nameEs,
        nameEn: product['product_name_en']?.toString(),
        portion: const Portion(amount: 100, unit: 'g'),
        nutrition: Nutrition(
          kcal: kcal,
          proteinG: protein,
          carbsG: carbs,
          fatG: fat,
        ),
        imageUrl: image,
        metadata: {
          'barcode': barcode,
          'brand': brand,
          'provider_raw_id': product['_id']?.toString(),
        },
      );
    } catch (_) {
      return null;
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
