import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/models/tracking_models.dart';
import '../../infrastructure/services/gemini_nlp_service.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_notifier.dart';
import '../widgets/nutrifoto_ui.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// VoiceScreen — Registro de alimentos por voz con NLP (Gemini + Fallback Regex)
// ═══════════════════════════════════════════════════════════════════════════════
// Flujo:
//  1. Usuario presiona micrófono → speech_to_text transcribe
//  2. Transcripción → GeminiNlpService parsea a JSON estructurado
//  3. Si Gemini falla → fallback regex local
//  4. Busca nutrientes en fuentes (local Chile → USDA/Edamam)
//  5. Registra automáticamente en el MealSlot correspondiente
// ═══════════════════════════════════════════════════════════════════════════════

class VoiceScreen extends StatefulWidget {
  final AppServices services;

  const VoiceScreen({super.key, required this.services});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  final _textCtrl = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechReady = false;
  bool _listening = false;
  bool _loading = false;
  bool _argsApplied = false;
  MealSlot _mealSlot = MealSlot.almuerzo;

  // Resultados del procesamiento
  List<_ProcessedFood> _processedFoods = [];
  String? _errorMessage;

  // Animación del botón de micrófono
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['mealSlot'] is MealSlot) {
      _mealSlot = args['mealSlot'] as MealSlot;
    }
    _argsApplied = true;
  }

  Future<void> _initSpeech() async {
    final ready = await _speech.initialize();
    if (!mounted) return;
    setState(() => _speechReady = ready);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    _textCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Speech-to-Text
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _toggleListening() async {
    HapticFeedback.lightImpact();

    if (!_speechReady) {
      setState(() => _errorMessage = 'Speech-to-Text no disponible en este dispositivo.');
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _listening = false);
      return;
    }

    setState(() {
      _errorMessage = null;
      _processedFoods = [];
    });

    await _speech.listen(
      localeId: 'es_ES',
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _textCtrl.text = result.recognizedWords;
          _textCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _textCtrl.text.length),
          );
        });
      },
    );

    if (!mounted) return;
    setState(() => _listening = true);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Procesamiento: Gemini NLP → Fallback Regex → Búsqueda Nutricional
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _processText() async {
    final input = _textCtrl.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = 'Ingresa una descripción primero.');
      return;
    }

    // Detener escucha si estaba activa
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _errorMessage = null;
      _processedFoods = [];
    });

    try {
      // ── Paso 1: Intentar parsing con Gemini NLP ──
      List<ParsedVoiceCommand>? parsed;
      parsed = await widget.services.geminiNlpService.parseVoiceTranscription(input);

      // ── Paso 2: Fallback a regex si Gemini no disponible ──
      if (parsed == null || parsed.isEmpty) {
        final regexResult = _fallbackRegexParse(input);
        if (regexResult != null) {
          parsed = [regexResult];
        }
      }

      if (parsed == null || parsed.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = 'No pude extraer alimentos del texto. Intenta con un formato como: "150 gramos de pollo al almuerzo".';
        });
        return;
      }

      // ── Paso 3: Buscar nutrientes y registrar cada alimento ──
      final results = <_ProcessedFood>[];

      for (final cmd in parsed) {
        final food = await _resolveNutrition(cmd);
        if (food == null) continue;

        // Usar el MealSlot del comando de Gemini, o el seleccionado manualmente
        final targetSlot = cmd.mealSlot;

        await widget.services.trackingUseCases.addFoodEntry(
          mealSlot: targetSlot,
          food: food,
        );

        results.add(_ProcessedFood(
          name: food.nameEs,
          kcal: food.nutrition.kcal,
          portion: food.portion.amount,
          unit: food.portion.unit,
          mealSlot: targetSlot,
          source: cmd.foodName == food.nameEs ? 'local' : 'API',
        ));
      }

      if (!mounted) return;

      if (results.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = 'No encontré nutrientes para los alimentos mencionados.';
        });
        return;
      }

      HapticFeedback.lightImpact();
      setState(() {
        _loading = false;
        _processedFoods = results;
      });

      final totalKcal = results.fold<double>(0, (sum, f) => sum + f.kcal);
      if (mounted) {
        AppNotifier.success(
          context,
          '${results.length} alimento${results.length > 1 ? 's' : ''} registrado${results.length > 1 ? 's' : ''} (${totalKcal.toStringAsFixed(0)} kcal)',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Error procesando: $e';
      });
    }
  }

  /// Resuelve la información nutricional del alimento parseado.
  /// Prioridad: Base local Chile → Búsqueda en USDA/Edamam
  Future<FoodItem?> _resolveNutrition(ParsedVoiceCommand cmd) async {
    final grams = cmd.grams;
    final ratio = grams / 100;

    // Intentar base local primero
    final local = widget.services.foodOrchestrator.resolveLocalClass(
      cmd.foodName.replaceAll(' ', '_').toLowerCase(),
    );

    if (local != null) {
      return FoodItem(
        source: local.source,
        itemId: local.itemId,
        nameEs: local.nameEs,
        nameEn: local.nameEn,
        portion: Portion(amount: grams, unit: 'g'),
        nutrition: Nutrition(
          kcal: local.nutrition.kcal * ratio,
          proteinG: local.nutrition.proteinG * ratio,
          carbsG: local.nutrition.carbsG * ratio,
          fatG: local.nutrition.fatG * ratio,
        ),
        confidence: 0.85,
        imageUrl: local.imageUrl,
        metadata: {'input_text': cmd.toString(), 'method': 'voice_gemini_local'},
      );
    }

    // Fallback: buscar en APIs externas
    final fallback = await widget.services.foodOrchestrator
        .searchFoodInSpanish(cmd.foodName);
    if (fallback.isEmpty) return null;

    final item = fallback.first;
    return FoodItem(
      source: item.source,
      itemId: item.itemId,
      nameEs: item.nameEs,
      nameEn: item.nameEn,
      portion: Portion(amount: grams, unit: 'g'),
      nutrition: Nutrition(
        kcal: item.nutrition.kcal * ratio,
        proteinG: item.nutrition.proteinG * ratio,
        carbsG: item.nutrition.carbsG * ratio,
        fatG: item.nutrition.fatG * ratio,
      ),
      confidence: 0.65,
      imageUrl: item.imageUrl,
      metadata: {'input_text': cmd.toString(), 'method': 'voice_gemini_api'},
    );
  }

  /// Fallback regex para cuando Gemini no está disponible.
  ParsedVoiceCommand? _fallbackRegexParse(String input) {
    final regex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(g|gramos?|kg|ml)\s+de\s+([a-zA-Z\u00C0-\u017F ]+)');
    final m = regex.firstMatch(input.toLowerCase());
    if (m == null) return null;

    final amountRaw = m.group(1)?.replaceAll(',', '.');
    final amount = double.tryParse(amountRaw ?? '');
    final unit = m.group(2) ?? 'gramos';
    final foodName = (m.group(3) ?? '').trim();
    if (amount == null || foodName.isEmpty) return null;

    return ParsedVoiceCommand(
      foodName: foodName,
      amount: amount,
      unit: unit,
      mealSlot: _mealSlot,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registro por Voz')),
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.hoy),
      body: AnimatedScreenBody(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const HeroPanel(
              title: 'Registro por Voz',
              subtitle: 'Habla naturalmente y registra alimentos con IA',
              gradient: NutrifotoColors.assistantGradient,
            ),
            const SizedBox(height: 16),

            // ── Botón de micrófono ──
            GlassCard(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _loading ? null : _toggleListening,
                      child: ScaleTransition(
                        scale: _listening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                        child: Semantics(
                          label: _listening ? 'Detener grabación' : 'Iniciar grabación de voz',
                          button: true,
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _listening
                                    ? [const Color(0xFFFF4D4D), const Color(0xFFD63031)]
                                    : [NutrifotoColors.primary.withValues(alpha: 0.9), NutrifotoColors.primarySoft],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_listening ? const Color(0xFFFF4D4D) : NutrifotoColors.primary)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _listening ? Icons.stop_rounded : Icons.mic_rounded,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _listening
                        ? '🎙️ Escuchando... Habla ahora'
                        : 'Toca el micrófono para hablar',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _listening ? const Color(0xFFFF4D4D) : null,
                    ),
                  ),
                  if (!_speechReady) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Speech-to-Text no inicializado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // ── Campo de texto editable ──
                  TextField(
                    controller: _textCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Transcripción (editable)',
                      hintText: 'Ej: "150 gramos de pollo al almuerzo"',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Selector de MealSlot (override manual) ──
                  DropdownButtonFormField<MealSlot>(
                    value: _mealSlot,
                    decoration: const InputDecoration(
                      labelText: 'Comida por defecto (Gemini puede sobrescribirlo)',
                    ),
                    items: MealSlot.values
                        .map((slot) => DropdownMenuItem(value: slot, child: Text(slot.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _mealSlot = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Botón de procesar ──
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _processText,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_loading ? 'Analizando con IA...' : 'Analizar y registrar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // ── Error ──
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB74D), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.orange.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Resultados exitosos ──
            if (_processedFoods.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '✅ Alimentos registrados',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              ...List.generate(_processedFoods.length, (i) {
                final food = _processedFoods[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassCard(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: NutrifotoColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.check_rounded, color: NutrifotoColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.name,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              Text(
                                '${food.portion.toStringAsFixed(0)}${food.unit} · ${food.kcal.toStringAsFixed(0)} kcal · ${food.mealSlot.label}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: NutrifotoColors.accentBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            food.source,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: NutrifotoColors.accentBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modelo interno para mostrar resultados procesados
class _ProcessedFood {
  final String name;
  final double kcal;
  final double portion;
  final String unit;
  final MealSlot mealSlot;
  final String source;

  const _ProcessedFood({
    required this.name,
    required this.kcal,
    required this.portion,
    required this.unit,
    required this.mealSlot,
    required this.source,
  });
}
