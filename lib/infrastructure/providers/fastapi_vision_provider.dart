import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/food_provider.dart';
import '../services/network_policy.dart';

class FastApiVisionProvider implements VisionProvider {
  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  FastApiVisionProvider({
    http.Client? client,
    required String baseUrl,
    Duration timeout = const Duration(seconds: 8),
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _timeout = timeout;

  @override
  Future<FoodItem?> classifyFood(String imagePath) async {
    try {
      final uri = Uri.parse('$_baseUrl/classify-food');
      final streamed = await runWithRetry(
        operation: () async {
          final request = http.MultipartRequest('POST', uri)
            ..files.add(await http.MultipartFile.fromPath('file', imagePath));
          return _client.send(request).timeout(_timeout);
        },
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final prediction =
          (json['prediction'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
      final nutritionJson =
          (json['nutrition'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};

      final className = prediction['class_name']?.toString() ?? 'alimento';
      final confidence = _asDouble(prediction['confidence']) ?? 0;

      final kcal = _asDouble(nutritionJson['kcal']) ?? 0;
      final protein = _asDouble(nutritionJson['protein_g']) ?? 0;
      final carbs = _asDouble(nutritionJson['carbs_g']) ?? 0;
      final fat = _asDouble(nutritionJson['fat_g']) ?? 0;

      return FoodItem(
        source: FoodSource.aiVision,
        itemId: prediction['id']?.toString() ?? className,
        nameEs: className,
        nameEn: prediction['class_name_en']?.toString(),
        portion: Portion(
          amount: _asDouble(json['portion_amount']) ?? 100,
          unit: json['portion_unit']?.toString() ?? 'g',
        ),
        nutrition: Nutrition(
          kcal: kcal,
          proteinG: protein,
          carbsG: carbs,
          fatG: fat,
        ),
        confidence: confidence,
        metadata: {
          'class_name': className,
          'bounding_box': prediction['bounding_box'],
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
