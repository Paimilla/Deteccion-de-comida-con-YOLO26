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
  final String _groqApiKey;
  static const String _model = 'gemini-3.1-flash-lite';
  final http.Client _client;

  GeminiNlpService({
    required String apiKey,
    String groqApiKey = '',
    http.Client? client,
  })  : _apiKey = apiKey,
        _groqApiKey = groqApiKey,
        _client = client ?? http.Client();

  // ── System Instruction exacto para el parser ──────────────────────────────
  // Gemini actuará como un extractor determinístico de entidades alimenticias.
  static const String systemInstruction = '''
Eres un experto en nutrición y análisis de lenguaje natural.
Tu tarea es extraer alimentos de una frase y devolver un ARRAY JSON de objetos.

REGLAS CRÍTICAS:
1. SIEMPRE devuelve una LISTA (array `[]`), incluso si solo hay un alimento.
2. Si el usuario menciona múltiples alimentos (ej: "pollo con arroz"), DEBES crear un objeto separado para CADA UNO.
3. Estima las calorías (kcal), proteínas, carbohidratos y grasas por la cantidad mencionada.
4. Si no menciona cantidad, asume 100g.

FORMATO DE CADA OBJETO:
{
  "alimento": "nombre en español",
  "cantidad": 100,
  "unidad": "gramos",
  "comida": "desayuno|almuerzo|cena|once|snack",
  "kcal": 250,
  "proteina": 20,
  "carbohidratos": 30,
  "grasa": 10
}
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
  Future<List<ParsedVoiceCommand>?> parseVoiceTranscription(String transcription, {MealSlot? currentMealSlot}) async {
    // Si no hay Groq API Key, intentamos Gemini directamente
    if (_groqApiKey.isEmpty) {
      return _parseWithGemini(transcription, currentMealSlot: currentMealSlot);
    }

    try {
      debugPrint('🚀 Groq NLP (Primary): parsing "$transcription"');
      final fullPrompt = '$systemInstruction\n\nCONTEXTO ACTUAL: El usuario está en el bloque de "${currentMealSlot?.label ?? 'almuerzo'}". Si no especifica lo contrario, usa este bloque.\n\nAnaliza este comando de voz y genera el JSON: "$transcription"';
      
      final groqResult = await _callGroqBackup(fullPrompt, isJson: true);
      if (groqResult != null) {
        try {
          final decoded = jsonDecode(groqResult);
          List<dynamic> items;

          if (decoded is List) {
            items = decoded;
          } else if (decoded is Map) {
            // Buscar si hay una lista dentro de alguna clave común
            final listKey = decoded.keys.firstWhere(
              (k) => decoded[k] is List,
              orElse: () => '',
            );
            if (listKey.isNotEmpty) {
              items = decoded[listKey] as List;
            } else {
              items = [decoded];
            }
          } else {
            items = [];
          }

          final List<ParsedVoiceCommand> results = [];
          
          for (var item in items) {
            if (item is! Map) continue;
            final data = item.cast<String, dynamic>();
            
            // Mapeo robusto de llaves
            final double? kcal = (data['kcal'] ?? data['calorias'] ?? data['calories'])?.toDouble();
            final double? protein = (data['proteina'] ?? data['proteinas'] ?? data['protein'] ?? data['proteins'])?.toDouble();
            final double? carbs = (data['carbohidratos'] ?? data['carbs'] ?? data['carbohydrates'] ?? data['choc'])?.toDouble();
            final double? fat = (data['grasa'] ?? data['grasas'] ?? data['fat'] ?? data['fats'])?.toDouble();

            results.add(ParsedVoiceCommand(
              foodName: data['alimento'] ?? data['nombre'] ?? 'Alimento desconocido',
              amount: (data['cantidad'] ?? 100).toDouble(),
              unit: data['unidad'] ?? 'gramos',
              mealSlot: _parseMealSlot(data['comida'] ?? data['slot'] ?? 'almuerzo'),
              kcal: kcal,
              protein: protein,
              carbs: carbs,
              fat: fat,
            ));
          }
          debugPrint('✅ Groq parseó ${results.length} alimento(s)');
          return results;
        } catch (e) {
          debugPrint('❌ Error parseando JSON de Groq: $e');
        }
      }
      
      // Si Groq falla, intentamos Gemini como backup
      return _parseWithGemini(transcription, currentMealSlot: currentMealSlot);
    } catch (e) {
      debugPrint('❌ Error en Groq (Primary), intentando Gemini: $e');
      return _parseWithGemini(transcription, currentMealSlot: currentMealSlot);
    }
  }

  /// Backup parser usando Gemini
  Future<List<ParsedVoiceCommand>?> _parseWithGemini(String transcription, {MealSlot? currentMealSlot}) async {
    if (_apiKey.isEmpty) return null;

    try {
      debugPrint('🤖 Gemini NLP (Backup): parsing "$transcription"');

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final body = jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text': 'INSTRUCCIONES DE SISTEMA: $systemInstruction\n\nCONTEXTO ACTUAL: El usuario está en el bloque de "${currentMealSlot?.label ?? 'almuerzo'}". Si no especifica lo contrario, usa este bloque.\n\nMENSAJE DEL USUARIO: $transcription'
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'topP': 0.8,
          'topK': 10,
          'maxOutputTokens': 1024,
          'responseMimeType': 'application/json',
        }
      });

      final response = await _client
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null || text.trim().isEmpty) return null;

      final decoded = jsonDecode(text);
      List<dynamic> items;

      if (decoded is List) {
        items = decoded;
      } else if (decoded is Map) {
        final listKey = decoded.keys.firstWhere(
          (k) => decoded[k] is List,
          orElse: () => '',
        );
        items = listKey.isNotEmpty ? decoded[listKey] as List : [decoded];
      } else {
        items = [];
      }

      final List<ParsedVoiceCommand> results = [];

      for (final item in items) {
        if (item is! Map) continue;
        final data = item.cast<String, dynamic>();
        
        // Mapeo robusto de llaves
        final double? kcal = (data['kcal'] ?? data['calorias'] ?? data['calories'])?.toDouble();
        final double? protein = (data['proteina'] ?? data['proteinas'] ?? data['protein'] ?? data['proteins'])?.toDouble();
        final double? carbs = (data['carbohidratos'] ?? data['carbs'] ?? data['carbohydrates'] ?? data['choc'])?.toDouble();
        final double? fat = (data['grasa'] ?? data['grasas'] ?? data['fat'] ?? data['fats'])?.toDouble();

        results.add(ParsedVoiceCommand(
          foodName: data['alimento'] ?? data['nombre'] ?? 'Alimento desconocido',
          amount: (data['cantidad'] ?? 100).toDouble(),
          unit: data['unidad'] ?? 'gramos',
          mealSlot: _parseMealSlot(data['comida'] ?? data['slot'] ?? 'almuerzo'),
          kcal: kcal,
          protein: protein,
          carbs: carbs,
          fat: fat,
        ));
      }
      return results.isEmpty ? null : results;
    } catch (e) {
      debugPrint('❌ Error en Gemini backup: $e');
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
        'system_instruction': {
          'parts': [{'text': systemPrompt}]
        },
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
        if (_groqApiKey.isNotEmpty) {
          final groqResp = await _callGroqBackup(userMessage);
          if (groqResp != null) return groqResp;
        }
        return 'En este momento estoy analizando muchos datos. ¡Pero puedo decirte que vas por muy buen camino con tus metas de hoy!';
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final text = json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      
      return text?.trim();
    } catch (e) {
      debugPrint('❌ Error Chat Gemini (intentando Groq): $e');
      if (_groqApiKey.isNotEmpty) {
        final groqResp = await _callGroqBackup(userMessage);
        if (groqResp != null) return groqResp;
      }
      return 'Lo siento, estoy teniendo problemas para conectar con mi cerebro de IA. Pero recuerda: ¡tú puedes con tus metas de hoy!';
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
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        if (_groqApiKey.isNotEmpty) {
          final groqResult = await _callGroqBackup('Traduce de $source a $target: $text', source: source, target: target);
          if (groqResult != null) return groqResult;
        }
        return fallback;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final translated = json['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      return (translated?.trim() ?? fallback);
    } catch (e) {
      debugPrint('❌ Error en translate: $e');
      if (_groqApiKey.isNotEmpty) {
        final groqResult = await _callGroqBackup('Traduce de $source a $target: $text', source: source, target: target);
        if (groqResult != null) return groqResult;
      }
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
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        if (_groqApiKey.isNotEmpty) {
          final groqResult = await _callGroqBackup(prompt, isJson: true);
          if (groqResult != null) {
            final List<dynamic> translatedList = jsonDecode(groqResult);
            return translatedList.map((e) => e.toString()).toList();
          }
        }
        return texts;
      }

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
Traduce estos nombres de alimentos/platos de $source a español chileno.
Para cada uno, genera también una descripción gastronómica MUY corta (máximo 12 palabras) que suene profesional y apetitosa.

REGLAS:
- Los nombres deben sonar naturales en español, como los llamaría un chileno (ej: "Turkey Breast" → "Pechuga de Pavo")
- NO uses traducciones literales absurdas
- Si el nombre ya está en español, solo mejora la capitalización
- Las descripciones deben ser atractivas y breves

Formato: array JSON de strings, cada una: "Nombre en español | Descripción corta"
Sin markdown, sin explicaciones. Solo el JSON.

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
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        debugPrint('🤖 Gemini TranslateBatch Response: $text');
        final decoded = jsonDecode(text);
        if (decoded is Map && decoded.containsKey('platos')) {
          return (decoded['platos'] as List).map((e) => e.toString()).toList();
        }
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
        return titles;
      }
      
      debugPrint('❌ Gemini TranslateBatch failed with status: ${response.statusCode}');
      
      if (_groqApiKey.isNotEmpty) {
        final groqResult = await _callGroqBackup(prompt, isJson: true);
        if (groqResult != null) {
          final decoded = jsonDecode(groqResult);
          if (decoded is Map && decoded.containsKey('platos')) {
            return (decoded['platos'] as List).map((e) => e.toString()).toList();
          }
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
          return titles;
        }
      }
      
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
    String? timeOfDay,
  }) async {
    if (_apiKey.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
      );

      final timeInfo = timeOfDay != null ? 'Es de $timeOfDay.' : '';

      final prompt = '''
Hola Gemini, actúa como un coach nutricional experto para Nutrifoto AI.
El usuario se llama $userName. $timeInfo
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
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return text.trim();
      } else {
        debugPrint('❌ Gemini API Error (${response.statusCode}): ${response.body}');
        // INTENTO 1: Backup con Groq si hay llave
        if (_groqApiKey.isNotEmpty) {
          final groqAdvice = await _callGroqBackup(prompt);
          if (groqAdvice != null) return groqAdvice;
        }
        return _getFallbackAdvice(kcalLeft, proteinLeft, carbsLeft, fatLeft);
      }
    } catch (e) {
      debugPrint('❌ Error generando consejo AI (intentando Groq/Fallback): $e');
      if (_groqApiKey.isNotEmpty) {
        // Podríamos re-generar el prompt aquí si fuera necesario, pero ya está en el scope
        final groqAdvice = await _callGroqBackup("Dame un consejo nutricional breve para alguien que le faltan ${kcalLeft.round()} kcal.");
        if (groqAdvice != null) return groqAdvice;
      }
      return _getFallbackAdvice(kcalLeft, proteinLeft, carbsLeft, fatLeft);
    }
  }

  Future<String?> _callGroqBackup(String prompt, {bool isJson = false, String source = 'auto', String target = 'es'}) async {
    if (_groqApiKey.isEmpty) return null;
    try {
      debugPrint('🚀 Intentando Groq Backup (JSON: $isJson)...');
      final response = await _client.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system', 
              'content': isJson 
                ? (prompt.contains('experto en nutrición') ? prompt : 'Eres un traductor técnico. Responde ÚNICAMENTE con el objeto JSON solicitado. No incluyas explicaciones, ni texto introductorio, ni bloques de código. Solo el JSON puro.') 
                : 'Eres un traductor literal. Tu ÚNICA función es traducir el texto que recibes de $source a $target. No digas "La traducción es:", no des explicaciones, no saludes. Responde exclusivamente con la traducción directa. Si no puedes traducir el término o es un nombre propio, devuélvelo tal cual.'
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': isJson ? 1024 : 150,
          if (isJson) 'response_format': {'type': 'json_object'},
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String result = data['choices'][0]['message']['content'].toString().trim();
        
        // Limpieza extra: Quitar frases conversacionales que rompen las búsquedas
        if (!isJson) {
          result = result.replaceFirst(RegExp(r'^(la traducción es|the translation is|traducción|result|resultado):\s*', caseSensitive: false), '');
          // Quitar comillas si el modelo las puso por error
          if (result.startsWith('"') && result.endsWith('"')) {
            result = result.substring(1, result.length - 1);
          }
        }
        
        debugPrint('✅ Groq Backup exitoso: ${result.substring(0, result.length > 30 ? 30 : result.length)}...');
        return result;
      } else {
        debugPrint('❌ Groq API Error (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Falló también el backup de Groq: $e');
    }
    return null;
  }

  String _getFallbackAdvice(double kcal, double prot, double carbs, double fat) {
    if (kcal <= 0) return "¡Increíble! Has alcanzado tu meta de hoy. Mantente hidratado y descansa bien.";
    if (prot > 40) return "Tu cuerpo necesita proteína para recuperarse. ¡Un snack con huevo o pollo sería ideal ahora!";
    if (carbs > 60) return "Aún tienes espacio para algo de energía. Una fruta o cereales integrales te vendrían bien.";
    if (kcal > 500) return "Vas por buen camino. Recuerda que la consistencia es la clave del éxito.";
    return "¡Buen trabajo hoy! Sigue registrando tus comidas para mantener el control.";
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
  final double? kcal;
  final double? protein;
  final double? carbs;
  final double? fat;

  const ParsedVoiceCommand({
    required this.foodName,
    required this.amount,
    required this.unit,
    required this.mealSlot,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
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
