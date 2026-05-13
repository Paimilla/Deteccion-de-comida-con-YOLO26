import 'dart:convert';

import 'package:flutter/foundation.dart';
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
    String model = 'gemini-2.5-flash',
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

  static const String chatSystemInstruction = '''
Eres el Asistente Nutricional de Nutrifoto AI.
Tu objetivo es ayudar al usuario a entender su progreso diario, darle consejos de salud, recetas y motivación.
Tienes acceso total a los datos del diario del usuario y sus metas.

REGLAS DE ORO:
1. Sé amable, experto en nutrición y motivador.
2. Usa SIEMPRE los datos del contexto para responder preguntas sobre "hoy", "mi progreso" o "qué he comido".
3. Si el usuario ha cumplido sus metas de proteína, felicítalo efusivamente.
4. Si el usuario pregunta qué comer, sugiere alimentos basados en los macros que le faltan para completar su día.
5. Mantén las respuestas breves y legibles (máximo 2-3 párrafos).
6. Habla en español de forma cercana.

CONOCIMIENTO ACTUAL DE LA APP:
{{CONTEXT}}
''';

  /// Parsea una transcripción de voz y devuelve los alimentos estructurados.
  /// Retorna null si no puede parsear o si la API falla.
  Future<List<ParsedVoiceCommand>?> parseVoiceTranscription(String transcription) async {
    if (_apiKey.isEmpty) {
      debugPrint('⚠️ GeminiNlpService: API key vacía, usando fallback regex');
      return null;
    }

    try {
      debugPrint('🤖 Gemini NLP: parsing "$transcription"');

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
        debugPrint('❌ Gemini API error ${response.statusCode}: ${response.body}');
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

      debugPrint('📦 Gemini respuesta: $text');

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

      debugPrint('✅ Gemini parseó ${results.length} alimento(s)');
      return results;
    } catch (e) {
      debugPrint('❌ Error en GeminiNlpService: $e');
      return null;
    }
  }

  Future<String?> generateChatResponse({
    required String userMessage,
    required String appContext,
    List<Map<String, String>> history = const [],
  }) async {
    if (_apiKey.isEmpty) return 'Lo siento, no tengo conexión con mi cerebro de IA en este momento.';

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final systemPrompt = chatSystemInstruction.replaceFirst('{{CONTEXT}}', appContext);

      final List<Map<String, dynamic>> contents = [];
      
      // Añadir instrucciones del sistema como el primer mensaje del "modelo" o un prefijo del usuario
      // para máxima compatibilidad
      contents.add({
        'role': 'user',
        'parts': [{'text': 'INSTRUCCIONES DE SISTEMA: $systemPrompt\n\nMensaje del usuario a continuación.'}]
      });

      // Añadir historial si existe
      for (final msg in history) {
        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [{'text': msg['text']}]
        });
      }

      // Añadir mensaje actual
      contents.add({
        'role': 'user',
        'parts': [{'text': userMessage}]
      });

      final body = jsonEncode({
        'contents': contents,
        'generationConfig': {
          'temperature': 0.7,
          'topP': 0.95,
          'topK': 40,
          'maxOutputTokens': 1024,
        }
      });

      final response = await _client
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('❌ Gemini API Error (${response.statusCode}): ${response.body}');
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      
      return text?.trim();
    } catch (e) {
      debugPrint('❌ Error Chat Gemini: $e');
      return null;
    }
  }

  /// Traduce texto usando Gemini.
  Future<String> translate({
    required String text,
    required String source,
    required String target,
    required String fallback,
  }) async {
    if (_apiKey.isEmpty) return fallback;

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    'Traduce exactamente este texto de $source a $target. Responde SOLO con la traducción, sin explicaciones ni comillas.\n\nTexto: $text'
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 100,
        }
      });

      final response = await _client
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return fallback;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final translated = json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      return (translated?.trim() ?? fallback);
    } catch (_) {
      return fallback;
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

  /// Traduce múltiples textos usando Gemini en una sola llamada (Batch).
  Future<List<String>> translateBatch({
    required List<String> texts,
    required String source,
    required String target,
  }) async {
    if (_apiKey.isEmpty || texts.isEmpty) return texts;

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final prompt = '''
Traduce esta lista de textos de $source a $target. 
Si el texto contiene etiquetas HTML (como <p> o <b>), mantenlas intactas.
Responde ÚNICAMENTE con un array JSON de strings en el mismo orden.
Sin explicaciones, sin markdown, solo el JSON.

Textos:
${jsonEncode(texts)}
''';

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        }
      });

      final response = await _client
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return texts;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final resultText = json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (resultText == null) return texts;

      final List<dynamic> translatedList = jsonDecode(resultText);
      return translatedList.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('❌ Error en translateBatch: $e');
      return texts;
    }
  }

  /// Traduce títulos y genera descripciones cortas en una sola llamada.
  Future<List<String>> translateAndDescribeBatch({
    required List<String> titles,
    required String source,
    required String target,
  }) async {
    if (_apiKey.isEmpty || titles.isEmpty) return titles.map((t) => '$t | Una opción nutritiva.').toList();

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final prompt = '''
Traduce estos títulos de platos de $source a $target. 
Para cada plato, genera también una descripción culinaria MUY corta (máximo 12 palabras) que suene profesional y apetitosa.
Responde ÚNICAMENTE con un array JSON de strings donde cada elemento tenga el formato: "Título traducido | Descripción corta".
Manten el mismo orden. Sin markdown, solo el JSON.

Títulos:
${jsonEncode(titles)}
''';

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'responseMimeType': 'application/json',
        }
      });

      final response = await _client
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        debugPrint('🤖 Gemini TranslateBatch Response: $text');
        final List<dynamic> list = jsonDecode(text);
        return list.map((e) => e.toString()).toList();
      }
      debugPrint('❌ Gemini TranslateBatch failed with status: ${response.statusCode}');
      return titles.map((t) => '$t | Una opción nutritiva.').toList();
    } catch (e) {
      debugPrint('Error in translateAndDescribeBatch: $e');
      return titles.map((t) => '$t | Una opción nutritiva.').toList();
    }
  }
  /// Genera un consejo nutricional inteligente basado en los macros restantes del día.
  Future<String?> generateNutritionalAdvice({
    required double kcalLeft,
    required double proteinLeft,
    required double carbsLeft,
    required double fatLeft,
    required String userName,
  }) async {
    if (_apiKey.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final prompt = '''
Hola Gemini, actúa como un coach nutricional experto para Nutrifoto AI.
El usuario se llama $userName.
Estado actual del día (lo que le FALTA para llegar a su meta):
- Calorías restantes: ${kcalLeft.round()} kcal
- Proteína restante: ${proteinLeft.round()} g
- Carbohidratos restantes: ${carbsLeft.round()} g
- Grasas restantes: ${fatLeft.round()} g

Tu tarea:
1. Da un consejo BREVE y motivador (1-2 frases).
2. Si le falta mucha proteína, sugiere alimentos altos en proteína.
3. Si ya completó sus metas, felicítalo y dale un consejo para mantener el ritmo.
4. Si se pasó de calorías, dale un consejo de compensación ligera (ej. más agua, caminata).
5. Mantén el tono cercano, profesional y en español de Chile/Latinoamérica.
6. NO uses markdown complejo, solo texto plano. Máximo 40 palabras.
''';

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 150,
        }
      });

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text.trim();
      }
    } catch (e) {
      debugPrint('❌ Error generando consejo AI: $e');
    }
    return null;
  }

  /// Genera instrucciones de preparación cortas para un alimento.
  Future<String?> generateRecipeInstructions(String foodName) async {
    if (_apiKey.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final prompt = '''
Eres un chef experto. El usuario quiere preparar: "$foodName".
Genera 3 pasos de preparación MUY breves, claros y en español.
Usa este formato exacto:
1. [Paso 1]
2. [Paso 2]
3. [Paso 3]
Sin introducciones ni conclusiones. Máximo 15 palabras por paso.
''';

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 200,
        }
      });

      final response = await _client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text.trim();
      }
    } catch (e) {
      debugPrint('❌ Error generando receta AI: $e');
    }
    return null;
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
