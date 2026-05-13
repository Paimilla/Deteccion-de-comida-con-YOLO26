import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/food_provider.dart';
import '../services/network_policy.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// EdamamProvider — Búsqueda nutricional vía Edamam Food Database API
// ═══════════════════════════════════════════════════════════════════════════════
// API Docs: https://developer.edamam.com/edamam-docs-nutrition-api
// Free tier: 100 requests/min, 1000/day
//
// Se usa como complemento a USDA para obtener datos nutricionales
// cuando el usuario registra alimentos por voz.
// ═══════════════════════════════════════════════════════════════════════════════

class EdamamProvider implements FoodSearchProvider {
  final String _appId;
  final String _appKey;
  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  EdamamProvider({
    required String appId,
    required String appKey,
    http.Client? client,
    String baseUrl = 'https://api.edamam.com',
    Duration timeout = const Duration(seconds: 8),
  })  : _appId = appId,
        _appKey = appKey,
        _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _timeout = timeout;

  @override
  Future<List<FoodItem>> searchFood(String query) async {
    if (_appId.isEmpty || _appKey.isEmpty) {
      debugPrint('⚠️ EdamamProvider: API keys vacías, retornando lista vacía');
      return const [];
    }

    try {
      // Usar el endpoint de Food Database (parser)
      final uri = Uri.parse(
        '$_baseUrl/api/food-database/v2/parser'
        '?app_id=$_appId'
        '&app_key=$_appKey'
        '&ingr=${Uri.encodeComponent(query)}'
        '&nutrition-type=cooking',
      );

      final response = await runWithRetry(
        operation: () => _client.get(uri).timeout(_timeout),
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Edamam error ${response.statusCode}: ${response.body.substring(0, 200)}');
        return const [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final hints = (json['hints'] as List?) ?? [];

      final results = <FoodItem>[];

      for (final hint in hints.take(8)) {
        if (hint is! Map) continue;
        final food = (hint['food'] as Map?)?.cast<String, dynamic>();
        if (food == null) continue;

        final nutrients = (food['nutrients'] as Map?)?.cast<String, dynamic>() ?? {};

        final kcal = _asDouble(nutrients['ENERC_KCAL']) ?? 0;
        final protein = _asDouble(nutrients['PROCNT']) ?? 0;
        final carbs = _asDouble(nutrients['CHOCDF']) ?? 0;
        final fat = _asDouble(nutrients['FAT']) ?? 0;

        final label = food['label']?.toString() ?? 'Alimento';
        final foodId = food['foodId']?.toString() ?? 'edamam_${label.hashCode}';
        final image = food['image']?.toString();

        results.add(FoodItem(
          source: FoodSource.edamam,
          itemId: foodId,
          nameEs: label, // Edamam retorna en inglés por defecto
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
            'category': food['category']?.toString(),
            'categoryLabel': food['categoryLabel']?.toString(),
          },
        ));
      }

      debugPrint('✅ Edamam: ${results.length} resultado(s) para "$query"');
      return results;
    } catch (e) {
      debugPrint('❌ Error en EdamamProvider: $e');
      return const [];
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
