import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/tracking_models.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// GeminiNlpService — Parser de lenguaje natural usando Google Gemini
// ═══════════════════════════════════════════════════════════════════════════════
// Recibe una transcripción de voz en español y devuelve un objeto estructurado
// con el alimento, la cantidad, la unidad y el MealSlot destino.
//
// Utiliza la API REST de Gemini (generateContent) en lugar de un SDK nativo,
// para mantener la superficie de dependencias mínima.
// ═══════════════════════════════════════════════════════════════════════════════

class GeminiNlpService {
  final String _apiKey;
  final String _model;
  final http.Client _client;

  GeminiNlpService({
    required String apiKey,
    String model = 'gemini-2.0-flash',
    http.Client? client,
  })  : _apiKey = apiKey,
        _model = model,
        _client = client ?? http.Client();

  // ── System Instruction exacto para el parser ──────────────────────────────
  // Gemini actuará como un extractor determinístico de entidades alimenticias.
  static const String systemInstruction = '''
Eres un parser de comandos de voz para una aplicación de nutrición.
Tu ÚNICO trabajo es extraer información estructurada del texto del usuario.

REGLAS ESTRICTAS:
1. SIEMPRE responde con JSON válido y NADA MÁS. Sin explicaciones, sin markdown.
2. Extrae: alimento, cantidad, unidad y comida (bloque del día).
3. Si el usuario no menciona cantidad, estima una porción estándar en gramos.
4. Si el usuario no menciona comida, infiere según la hora actual o usa "almuerzo" por defecto.
5. Normaliza el nombre del alimento a su forma más simple en español.
6. Los valores válidos para "comida" son EXACTAMENTE: "desayuno", "almuerzo", "cena", "once", "snack".
7. Si el usuario menciona múltiples alimentos, devuelve un array JSON.

FORMATO DE RESPUESTA (un solo alimento):
{"alimento": "pechuga de pollo", "cantidad": 150, "unidad": "gramos", "comida": "almuerzo"}

FORMATO DE RESPUESTA (múltiples alimentos):
[
  {"alimento": "arroz", "cantidad": 200, "unidad": "gramos", "comida": "almuerzo"},
  {"alimento": "pollo", "cantidad": 150, "unidad": "gramos", "comida": "almuerzo"}
]

EJEMPLOS DE ENTRADA → SALIDA:
- "Agregame 150 gramos de pechuga de pollo al almuerzo" → {"alimento": "pechuga de pollo", "cantidad": 150, "unidad": "gramos", "comida": "almuerzo"}
- "Desayuné dos huevos fritos con pan" → [{"alimento": "huevos fritos", "cantidad": 120, "unidad": "gramos", "comida": "desayuno"}, {"alimento": "pan", "cantidad": 60, "unidad": "gramos", "comida": "desayuno"}]
- "Una manzana de snack" → {"alimento": "manzana", "cantidad": 180, "unidad": "gramos", "comida": "snack"}
- "Ayer cené dos manzanas" → [{"alimento": "manzana", "cantidad": 180, "unidad": "gramos", "comida": "cena"}, {"alimento": "manzana", "cantidad": 180, "unidad": "gramos", "comida": "cena"}]
''';

  /// Parsea una transcripción de voz y devuelve los alimentos estructurados.
  /// Retorna null si no puede parsear o si la API falla.
  Future<List<ParsedVoiceCommand>?> parseVoiceTranscription(String transcription) async {
    if (_apiKey.isEmpty) {
      // ignore: avoid_print
      print('⚠️ GeminiNlpService: API key vacía, usando fallback regex');
      return null;
    }

    try {
      // ignore: avoid_print
      print('🤖 Gemini NLP: parsing "$transcription"');

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final body = jsonEncode({
        'system_instruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
        'contents': [
          {
            'parts': [
              {'text': transcription}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1, // Determinístico
          'topP': 0.8,
          'topK': 10,
          'maxOutputTokens': 1024,
          'responseMimeType': 'application/json',
        }
      });

      final response = await _client
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('❌ Gemini API error ${response.statusCode}: ${response.body}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) return null;

      final text = (parts[0]['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) return null;

      // ignore: avoid_print
      print('📦 Gemini respuesta: $text');

      // Parsear JSON de respuesta (puede ser un objeto o un array)
      final parsed = jsonDecode(text);
      final List<dynamic> items;

      if (parsed is List) {
        items = parsed;
      } else if (parsed is Map) {
        items = [parsed];
      } else {
        return null;
      }

      final results = <ParsedVoiceCommand>[];
      for (final item in items) {
        if (item is! Map) continue;
        final data = item.cast<String, dynamic>();

        final alimento = data['alimento']?.toString().trim();
        if (alimento == null || alimento.isEmpty) continue;

        final cantidad = (data['cantidad'] as num?)?.toDouble() ?? 100.0;
        final unidad = data['unidad']?.toString() ?? 'gramos';
        final comidaStr = data['comida']?.toString().toLowerCase() ?? 'almuerzo';

        final mealSlot = _parseMealSlot(comidaStr);

        results.add(ParsedVoiceCommand(
          foodName: alimento,
          amount: cantidad,
          unit: unidad,
          mealSlot: mealSlot,
        ));
      }

      if (results.isEmpty) return null;

      // ignore: avoid_print
      print('✅ Gemini parseó ${results.length} alimento(s)');
      return results;
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error en GeminiNlpService: $e');
      return null;
    }
  }

  MealSlot _parseMealSlot(String text) {
    switch (text) {
      case 'desayuno':
        return MealSlot.desayuno;
      case 'almuerzo':
        return MealSlot.almuerzo;
      case 'cena':
        return MealSlot.cena;
      case 'once':
        return MealSlot.once;
      case 'snack':
        return MealSlot.snack;
      default:
        return MealSlot.almuerzo;
    }
  }
}

/// Resultado estructurado de la interpretación de un comando de voz.
class ParsedVoiceCommand {
  final String foodName;
  final double amount;
  final String unit;
  final MealSlot mealSlot;

  const ParsedVoiceCommand({
    required this.foodName,
    required this.amount,
    required this.unit,
    required this.mealSlot,
  });

  /// Convierte la cantidad a gramos para normalizar las porciones.
  double get grams {
    switch (unit.toLowerCase()) {
      case 'kg':
      case 'kilogramos':
      case 'kilogramo':
        return amount * 1000;
      case 'oz':
      case 'onzas':
      case 'onza':
        return amount * 28.35;
      case 'lb':
      case 'libras':
      case 'libra':
        return amount * 453.59;
      case 'ml':
      case 'mililitros':
        return amount; // Aproximación 1:1 para líquidos acuosos
      case 'taza':
      case 'tazas':
        return amount * 240;
      case 'cucharada':
      case 'cucharadas':
        return amount * 15;
      case 'cucharadita':
      case 'cucharaditas':
        return amount * 5;
      case 'unidad':
      case 'unidades':
      case 'pieza':
      case 'piezas':
        return amount * 150; // Estimación genérica
      default:
        return amount; // Asumimos gramos por defecto
    }
  }

  @override
  String toString() =>
      'ParsedVoiceCommand(food: $foodName, amount: $amount $unit → ${grams.toStringAsFixed(0)}g, meal: ${mealSlot.name})';
}
