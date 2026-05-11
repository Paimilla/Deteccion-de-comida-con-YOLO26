import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/repositories/food_provider.dart';
import 'network_policy.dart';

class LibreTranslateService implements TranslationService {
  final http.Client _client;
  final String _baseUrl;
  final String? _apiKey;
  final Duration _timeout;

  LibreTranslateService({
    http.Client? client,
    String baseUrl = 'https://libretranslate.com',
    String? apiKey,
    Duration timeout = const Duration(seconds: 5),
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _apiKey = apiKey,
        _timeout = timeout;

  @override
  Future<String> toEnglish(String textEs) async {
    return _translate(
      text: textEs,
      source: 'es',
      target: 'en',
      fallback: textEs,
    );
  }

  @override
  Future<String> toSpanish(String textEn) async {
    return _translate(
      text: textEn,
      source: 'en',
      target: 'es',
      fallback: textEn,
    );
  }

  Future<String> _translate({
    required String text,
    required String source,
    required String target,
    required String fallback,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/translate');
      final payload = <String, dynamic>{
        'q': text,
        'source': source,
        'target': target,
        'format': 'text',
      };
      final apiKey = _apiKey;
      if (apiKey != null && apiKey.isNotEmpty) {
        payload['api_key'] = apiKey;
      }

      final response = await runWithRetry(
        operation: () => _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(_timeout),
      );

      if (response.statusCode != 200) {
        return fallback;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final translated = json['translatedText']?.toString();
      if (translated == null || translated.isEmpty) {
        return fallback;
      }
      return translated;
    } catch (_) {
      return fallback;
    }
  }
}
