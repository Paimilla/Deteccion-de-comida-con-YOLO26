import '../../domain/repositories/food_provider.dart';
import 'gemini_nlp_service.dart';

class GeminiTranslationService implements TranslationService {
  final GeminiNlpService _gemini;

  GeminiTranslationService(this._gemini);

  @override
  Future<String> toEnglish(String textEs) async {
    return _gemini.translate(
      text: textEs,
      source: 'español',
      target: 'inglés',
      fallback: textEs,
    );
  }

  @override
  Future<String> toSpanish(String textEn) async {
    return _gemini.translate(
      text: textEn,
      source: 'inglés',
      target: 'español',
      fallback: textEn,
    );
  }

  @override
  Future<List<String>> translateBatch({
    required List<String> texts,
    required String source,
    required String target,
  }) async {
    return _gemini.translateBatch(
      texts: texts,
      source: source,
      target: target,
    );
  }

  @override
  Future<List<String>> translateAndDescribeBatch({
    required List<String> titles,
    required String source,
    required String target,
  }) async {
    return _gemini.translateAndDescribeBatch(
      titles: titles,
      source: source,
      target: target,
    );
  }
}
