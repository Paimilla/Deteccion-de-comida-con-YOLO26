import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/tracking_models.dart';

// Brand purple accent (Nutrifoto palette)
const Color _accent = Color(0xFF8F62FF);
const Color _accentSoft = Color(0xFF7448F0);
const Color _cardBg = Color(0xFF1A1A2E);
const Color _bodyText = Color(0xFF9CA3AF);

/// Complete Fitia-style onboarding with all steps.
class OnboardingScreen extends StatefulWidget {
  final AppServices services;
  const OnboardingScreen({super.key, required this.services});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();

  // Steps:
  // 0  Intro
  // 1  Objetivo (Perder Grasa / Ganar Musculo / Mantener Peso)
  // 2  Como conseguirlo (plan / contar)
  // 3  Sobre ti (Sexo/Edad/Altura/Peso)
  // 4  Nivel de actividad (0-5 days)
  // 5  Entrenamientos de fuerza (Si / No)
  // 6  Estilo de vida (sedentario..intenso)
  // 7  Personaliza objetivo (Peso actual/objetivo/velocidad)
  // 8  Nombre
  // 9  Resumen
  static const _stepsCount = 10;
  int _step = 0;

  // Data
  String _name = '';
  String _gender = 'Hombre';
  int _age = 25;
  double _height = 170;
  double _weight = 70;
  double _goalWeight = 69;
  String _objective = '';
  String _approach = '';
  String _activityLevel = '';     // step 4
  String _strengthTraining = '';  // step 5: 'Si' or 'No'
  String _lifestyle = '';         // step 6
  String _lossSpeed = 'Recomendado'; // step 7
  bool _isSaving = false;
  int _savingPhase = 0;

  bool _argsApplied = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsApplied) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['prefillName'] is String) {
      final prefill = args['prefillName'] as String;
      if (prefill.isNotEmpty) {
        _name = prefill;
      }
    }
    _argsApplied = true;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _exercisePerWeek {
    switch (_activityLevel) {
      case 'No Hago Ejercicio': return 0;
      case '1-2 Dias por Semana': return 2;
      case '3-4 dias por Semana': return 4;
      case '5-6 dias por Semana': return 6;
      case 'Diario': return 7;
      default: return 3;
    }
  }

  double get _activityMultiplier {
    switch (_lifestyle) {
      case 'Mayormente sentado': return 1.2;
      case 'A veces de pie': return 1.375;
      case 'Mayormente de pie': return 1.55;
      case 'En movimiento todo el dia': return 1.725;
      case 'Trabajo fisico intenso': return 1.9;
      default: return 1.375;
    }
  }

  double get _speedMultiplier {
    switch (_lossSpeed) {
      case 'Rapido': return 1.4;
      case 'Lento': return 0.6;
      default: return 1.0; // Recomendado
    }
  }

  bool get _canContinue {
    switch (_step) {
      case 0: return true;
      case 1: return _objective.isNotEmpty;
      case 2: return _approach.isNotEmpty;
      case 3: return true;
      case 4: return _activityLevel.isNotEmpty;
      case 5: return _strengthTraining.isNotEmpty;
      case 6: return _lifestyle.isNotEmpty;
      case 7: return true;
      case 8: return _name.trim().isNotEmpty;
      case 9: return true;
      default: return false;
    }
  }

  void _next() {
    if (!_canContinue) {
      HapticFeedback.mediumImpact();
      return;
    }
    HapticFeedback.lightImpact();
    if (_step < _stepsCount - 1) {
      setState(() => _step += 1);
      _pageController.animateToPage(_step,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    } else {
      _completeRegistration();
    }
  }

  void _prev() {
    if (_step > 0) {
      HapticFeedback.lightImpact();
      setState(() => _step -= 1);
      _pageController.animateToPage(_step,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    } else {
      // Paso 0: volver a la pantalla de bienvenida
      HapticFeedback.lightImpact();
      Navigator.pushReplacementNamed(context, AppRoutes.welcome);
    }
  }

  Future<void> _completeRegistration() async {
    if (_isSaving) return;
    setState(() { _isSaving = true; _savingPhase = 0; });

    final kcalBase = _calcKcal();
    final protein = (_weight * (_strengthTraining == 'Si' ? 2.2 : 1.8)).clamp(80.0, 250.0);
    final fat = (_weight * 0.8).clamp(40.0, 120.0);
    final carbs = ((kcalBase - (protein * 4) - (fat * 9)) / 4).clamp(100.0, 450.0);

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    setState(() => _savingPhase = 1);
    await widget.services.trackingUseCases.setNutritionGoals(NutritionGoals(
      kcal: kcalBase, proteinG: protein, carbsG: carbs, fatG: fat,
    ));

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    setState(() => _savingPhase = 2);
    await widget.services.trackingUseCases.saveUserProfile(UserProfile(
      name: _name.trim(), gender: _gender, weightKg: _weight,
      heightCm: _height, age: _age, exercisePerWeek: _exercisePerWeek,
      createdAt: DateTime.now(),
    ));

    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    setState(() => _savingPhase = 3);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    // Go to signup (final registration step)
    await Navigator.pushReplacementNamed(context, AppRoutes.signup);
  }

  double _calcKcal() {
    // Mifflin-St Jeor BMR
    final genderBias = _gender == 'Hombre' ? 5.0 : -161.0;
    final bmr = (10 * _weight) + (6.25 * _height) - (5 * _age) + genderBias;

    // TDEE = BMR * lifestyle multiplier + exercise boost
    final tdee = bmr * _activityMultiplier;
    // Exercise boost: each exercise day adds ~50-80 kcal on top of TDEE
    final exerciseBoost = _exercisePerWeek * 60.0;
    final totalTdee = tdee + exerciseBoost;

    // Strength training slightly increases protein needs (handled elsewhere)
    // but also increases TDEE slightly
    final strengthBonus = _strengthTraining == 'Si' ? 100.0 : 0.0;

    // Apply objective offset scaled by speed
    double offset = 0;
    if (_objective == 'Perder Grasa') {
      offset = -400 * _speedMultiplier;
    } else if (_objective == 'Ganar Musculo') {
      offset = 350 * _speedMultiplier;
    }
    return (totalTdee + strengthBonus + offset).clamp(1200, 4500).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_step > 0) {
          _prev();
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.welcome);
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top bar — siempre visible con botón de volver
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _prev,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _ProgressBar(progress: (_step + 1) / _stepsCount)),
                    ],
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _IntroPage(),
                      _ObjectivePage(selected: _objective, onChanged: (v) => setState(() => _objective = v)),
                      _ApproachPage(selected: _approach, onChanged: (v) => setState(() => _approach = v)),
                      _AboutYouPage(
                        gender: _gender, age: _age, height: _height, weight: _weight,
                        onGenderChanged: (v) => setState(() => _gender = v),
                        onAgeChanged: (v) => setState(() => _age = v),
                        onHeightChanged: (v) => setState(() => _height = v),
                        onWeightChanged: (v) => setState(() => _weight = v),
                      ),
                      _ActivityLevelPage(selected: _activityLevel, onChanged: (v) => setState(() => _activityLevel = v)),
                      _StrengthTrainingPage(selected: _strengthTraining, onChanged: (v) => setState(() => _strengthTraining = v)),
                      _LifestylePage(selected: _lifestyle, onChanged: (v) => setState(() => _lifestyle = v)),
                      _CustomizeGoalPage(
                        currentWeight: _weight, goalWeight: _goalWeight, speed: _lossSpeed,
                        objective: _objective,
                        onGoalWeightChanged: (v) => setState(() => _goalWeight = v),
                        onSpeedChanged: (v) => setState(() => _lossSpeed = v),
                      ),
                      _NamePage(name: _name, onChanged: (v) => setState(() => _name = v)),
                      _SummaryPage(
                        kcal: _calcKcal().round(),
                        protein: (_weight * (_strengthTraining == 'Si' ? 2.2 : 1.8)).clamp(80, 250).round(),
                        carbs: (((_calcKcal() - ((_weight * (_strengthTraining == 'Si' ? 2.2 : 1.8)).clamp(80, 250) * 4) - ((_weight * 0.8).clamp(40, 120) * 9)) / 4).clamp(100, 450)).round(),
                        fat: (_weight * 0.8).clamp(40, 120).round(),
                        objective: _objective,
                      ),
                    ],
                  ),
                ),

                // Bottom button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity, height: 56,
                    child: GestureDetector(
                      onTap: _next,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _canContinue ? _accent : const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _canContinue ? [BoxShadow(color: _accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))] : null,
                        ),
                        child: Center(
                          child: Text(
                            _step == 7 ? 'Crear Mi Plan' : _step == _stepsCount - 1 ? 'Finalizar' : 'Continuar',
                            style: TextStyle(
                              color: _canContinue ? Colors.white : Colors.white.withValues(alpha: 0.3),
                              fontSize: 17, fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isSaving) _SavingOverlay(phase: _savingPhase, kcal: _calcKcal().round(),
            protein: (_weight * (_strengthTraining == 'Si' ? 2.2 : 1.8)).clamp(80, 250).round(),
            carbs: (((_calcKcal() - ((_weight * (_strengthTraining == 'Si' ? 2.2 : 1.8)).clamp(80, 250) * 4) - ((_weight * 0.8).clamp(40, 120) * 9)) / 4).clamp(100, 450)).round(),
            fat: (_weight * 0.8).clamp(40, 120).round(),
          ),
        ],
      ),
    ),
    );
  }
}

// ==================== SHARED WIDGETS ====================

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(99)),
      child: LayoutBuilder(
        builder: (context, c) => Stack(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic,
            width: c.maxWidth * progress, height: 4,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_accent, _accentSoft]),
              borderRadius: BorderRadius.circular(99),
              boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.4), blurRadius: 6)],
            ),
          ),
        ]),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionCard({this.icon, this.emoji, this.iconColor, required this.title, this.subtitle, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _accent.withValues(alpha: 0.1) : _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _accent : Colors.white.withValues(alpha: 0.06), width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            if (emoji != null) ...[
              Text(emoji!, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
            ] else if (icon != null) ...[
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: (iconColor ?? _accent).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor ?? _accent, size: 24),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: selected ? _accent : Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback onTap;

  const _FieldRow({required this.icon, required this.label, required this.value, this.valueColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _accent, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
            Text(value, style: TextStyle(color: valueColor ?? Colors.white.withValues(alpha: 0.7), fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final String title;
  final int itemCount;
  final int initialItem;
  final String Function(int) itemBuilder;
  final ValueChanged<int> onConfirm;
  const _PickerSheet({required this.title, required this.itemCount, required this.initialItem, required this.itemBuilder, required this.onConfirm});

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late int _selectedIndex;
  @override
  void initState() { super.initState(); _selectedIndex = widget.initialItem; }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320, padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99))),
        const SizedBox(height: 14),
        Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Expanded(
          child: CupertinoPicker(
            scrollController: FixedExtentScrollController(initialItem: widget.initialItem),
            itemExtent: 44, magnification: 1.2, squeeze: 0.9, useMagnifier: true,
            selectionOverlay: Container(decoration: BoxDecoration(color: _accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12))),
            onSelectedItemChanged: (i) { HapticFeedback.selectionClick(); _selectedIndex = i; },
            children: List.generate(widget.itemCount, (i) => Center(child: Text(widget.itemBuilder(i), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)))),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: GestureDetector(
              onTap: () { widget.onConfirm(_selectedIndex); Navigator.pop(context); },
              child: Container(
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('OK', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ==================== STEP PAGES ====================

// STEP 0: Intro
class _IntroPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Container(
            width: 180, height: 180,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _accent.withValues(alpha: 0.06)),
            child: Center(child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _accent.withValues(alpha: 0.12)),
              child: Center(child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _accent.withValues(alpha: 0.2)),
                child: const Center(child: Icon(Icons.local_fire_department, color: _accent, size: 40)),
              )),
            )),
          ),
          const SizedBox(height: 40),
          const Text('Perfecto! Primero\ndescubramos cuantas\ncalorias necesitas al dia',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// STEP 1: Objetivo
class _ObjectivePage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _ObjectivePage({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 20),
        _PageIcon(icon: Icons.track_changes),
        const SizedBox(height: 20),
        const Text('Cual es tu objetivo?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Calcularemos tus calorias necesarias\npara lograrlo', textAlign: TextAlign.center, style: TextStyle(color: _bodyText, fontSize: 14)),
        const SizedBox(height: 36),
        _SelectionCard(icon: Icons.local_fire_department, iconColor: const Color(0xFFEF4444), title: 'Perder Grasa', subtitle: 'Optimiza la perdida de peso y conserva tu masa muscular', selected: selected == 'Perder Grasa', onTap: () => onChanged('Perder Grasa')),
        const SizedBox(height: 10),
        _SelectionCard(icon: Icons.fitness_center, iconColor: const Color(0xFF10B981), title: 'Ganar Musculo', subtitle: 'Incrementa tu peso y hazte mas fuerte', selected: selected == 'Ganar Musculo', onTap: () => onChanged('Ganar Musculo')),
        const SizedBox(height: 10),
        _SelectionCard(icon: Icons.favorite, iconColor: const Color(0xFFEC4899), title: 'Mantener Peso', subtitle: 'Manten tu peso estable y busca la recomposicion corporal', selected: selected == 'Mantener Peso', onTap: () => onChanged('Mantener Peso')),
      ]),
    );
  }
}

// STEP 2: Approach
class _ApproachPage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _ApproachPage({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 20),
        _PageIcon(icon: Icons.flag),
        const SizedBox(height: 20),
        const Text('Como deseas\nconseguirlo?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        const Text('No te preocupes, luego lo puedes cambiar', style: TextStyle(color: _bodyText, fontSize: 14)),
        const SizedBox(height: 20),
        _SelectionCard(icon: Icons.restaurant_menu, iconColor: _accent, title: 'Necesito un plan nutricional', subtitle: 'No se que comer. Necesito sugerencias de comidas', selected: selected == 'plan', onTap: () => onChanged('plan')),
        const SizedBox(height: 10),
        _SelectionCard(icon: Icons.calculate, iconColor: _accentSoft, title: 'Necesito contar mis calorias', subtitle: 'Se que comer. Necesito monitorear mis calorias y macronutrientes', selected: selected == 'contar', onTap: () => onChanged('contar')),
      ]),
    );
  }
}

// STEP 3: About You
class _AboutYouPage extends StatelessWidget {
  final String gender; final int age; final double height; final double weight;
  final ValueChanged<String> onGenderChanged;
  final ValueChanged<int> onAgeChanged;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<double> onWeightChanged;

  const _AboutYouPage({required this.gender, required this.age, required this.height, required this.weight, required this.onGenderChanged, required this.onAgeChanged, required this.onHeightChanged, required this.onWeightChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 20),
        _PageIcon(icon: Icons.badge),
        const SizedBox(height: 20),
        const Text('Sobre ti', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Esta informacion nos ayudara a calcular\ntus calorias objetivo', textAlign: TextAlign.center, style: TextStyle(color: _bodyText, fontSize: 14)),
        const SizedBox(height: 28),
        _FieldRow(icon: Icons.person, label: 'Sexo', value: gender, onTap: () => _showPicker(context, 'Sexo', ['Hombre', 'Mujer'], ['Hombre', 'Mujer'].indexOf(gender).clamp(0, 1), (i) => onGenderChanged(['Hombre', 'Mujer'][i]))),
        const SizedBox(height: 10),
        _FieldRow(icon: Icons.cake, label: 'Edad', value: '$age años', onTap: () => _showPicker(context, 'Edad', List.generate(91, (i) => '${i + 10}  años'), (age - 10).clamp(0, 90), (i) => onAgeChanged(i + 10))),
        const SizedBox(height: 10),
        _FieldRow(icon: Icons.straighten, label: 'Altura', value: '${height.toStringAsFixed(0)} cm', onTap: () => _showPicker(context, 'Altura', List.generate(151, (i) => '${i + 100}  cm'), (height.round() - 100).clamp(0, 150), (i) => onHeightChanged((i + 100).toDouble()))),
        const SizedBox(height: 10),
        _FieldRow(icon: Icons.monitor_weight, label: 'Peso', value: '${weight.toStringAsFixed(1)} kg', onTap: () => _showPicker(context, 'Peso', List.generate(171, (i) => '${i + 30}  kg'), (weight.round() - 30).clamp(0, 170), (i) => onWeightChanged((i + 30).toDouble()))),
      ]),
    );
  }

  void _showPicker(BuildContext context, String title, List<String> items, int initial, ValueChanged<int> onConfirm) {
    showModalBottomSheet(context: context, backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PickerSheet(title: title, itemCount: items.length, initialItem: initial, itemBuilder: (i) => items[i], onConfirm: onConfirm));
  }
}

// STEP 4: Activity Level
class _ActivityLevelPage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _ActivityLevelPage({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 20),
        _PageIcon(icon: Icons.sports_martial_arts),
        const SizedBox(height: 20),
        const Text('Cual es tu nivel de\nactividad?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 28),
        _SelectionCard(emoji: '\u{1F6AB}', title: 'No Hago Ejercicio', selected: selected == 'No Hago Ejercicio', onTap: () => onChanged('No Hago Ejercicio')),
        const SizedBox(height: 10),
        _SelectionCard(emoji: '\u{1F525}', title: '1-2 Dias por Semana', selected: selected == '1-2 Dias por Semana', onTap: () => onChanged('1-2 Dias por Semana')),
        const SizedBox(height: 10),
        _SelectionCard(emoji: '\u{1F525}', title: '3-4 dias por Semana', selected: selected == '3-4 dias por Semana', onTap: () => onChanged('3-4 dias por Semana')),
        const SizedBox(height: 10),
        _SelectionCard(emoji: '\u{1F525}', title: '5-6 dias por Semana', selected: selected == '5-6 dias por Semana', onTap: () => onChanged('5-6 dias por Semana')),
        const SizedBox(height: 10),
        _SelectionCard(emoji: '\u{1F525}', title: 'Diario', selected: selected == 'Diario', onTap: () => onChanged('Diario')),
        const SizedBox(height: 12),
        const Text('No te preocupes, luego lo puedes cambiar', style: TextStyle(color: _bodyText, fontSize: 13)),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// STEP 5: Strength Training
class _StrengthTrainingPage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _StrengthTrainingPage({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 20),
        _PageIcon(icon: Icons.fitness_center),
        const SizedBox(height: 20),
        const Text('Realizas entrenamientos\nde fuerza?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Esta informacion es clave para\ndeterminar tu ingesta de proteina', textAlign: TextAlign.center, style: TextStyle(color: _bodyText, fontSize: 14)),
        const SizedBox(height: 40),
        _SelectionCard(emoji: '\u2705', title: 'Si', selected: selected == 'Si', onTap: () => onChanged('Si')),
        const SizedBox(height: 10),
        _SelectionCard(emoji: '\u274C', title: 'No', selected: selected == 'No', onTap: () => onChanged('No')),
        const SizedBox(height: 16),
        const Text('Los entrenamientos de fuerza implican\ndesafiar tus musculos con pesas, bandas o tu\npropio peso corporal', textAlign: TextAlign.center, style: TextStyle(color: _bodyText, fontSize: 13)),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// STEP 6: Lifestyle
class _LifestylePage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _LifestylePage({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 20),
        _PageIcon(icon: Icons.directions_run),
        const SizedBox(height: 20),
        const Text('Cual es tu estilo de vida?', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Solo toma en consideracion\ntu movimiento diario, no tus\nentrenamientos.', textAlign: TextAlign.center, style: TextStyle(color: _bodyText, fontSize: 14)),
        const SizedBox(height: 28),
        _SelectionCard(emoji: '\u{1F9D1}\u200D\u{1F4BB}', title: 'Mayormente sentado', subtitle: 'Trabajo de escritorio o desde casa', selected: selected == 'Mayormente sentado', onTap: () => onChanged('Mayormente sentado')),
        const SizedBox(height: 10),
        _SelectionCard(emoji: '\u{1F9CD}', title: 'A veces de pie', subtitle: 'Mezcla de estar sentado y moverte', selected: selected == 'A veces de pie', onTap: () => onChanged('A veces de pie')),
        const SizedBox(height: 10),
        _SelectionCard(emoji: '\u{1F6B6}', title: 'Mayormente de pie', subtitle: 'De pie o caminando con regularidad', selected: selected == 'Mayormente de pie', onTap: () => onChanged('Mayormente de pie')),
        const SizedBox(height: 10),
        _SelectionCard(emoji: '\u{1F3C3}', title: 'En movimiento todo el dia', subtitle: 'Trabajo fisico o caminatas frecuentes', selected: selected == 'En movimiento todo el dia', onTap: () => onChanged('En movimiento todo el dia')),
        const SizedBox(height: 10),
        _SelectionCard(emoji: '\u{1F4AA}', title: 'Trabajo fisico intenso', subtitle: 'Labor pesada', selected: selected == 'Trabajo fisico intenso', onTap: () => onChanged('Trabajo fisico intenso')),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// STEP 7: Customize Goal
class _CustomizeGoalPage extends StatelessWidget {
  final double currentWeight;
  final double goalWeight;
  final String speed;
  final String objective;
  final ValueChanged<double> onGoalWeightChanged;
  final ValueChanged<String> onSpeedChanged;

  const _CustomizeGoalPage({required this.currentWeight, required this.goalWeight, required this.speed, required this.objective, required this.onGoalWeightChanged, required this.onSpeedChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 20),
        _PageIcon(icon: Icons.edit),
        const SizedBox(height: 20),
        const Text('Personaliza tu objetivo', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Ultimo paso para conocer tus calorias y\nmacros', textAlign: TextAlign.center, style: TextStyle(color: _bodyText, fontSize: 14)),
        const SizedBox(height: 36),
        _FieldRow(icon: Icons.monitor_weight, label: 'Peso actual', value: '${currentWeight.toStringAsFixed(0)} kg', onTap: () {}),
        const SizedBox(height: 10),
        _FieldRow(icon: Icons.track_changes, label: 'Peso objetivo', value: goalWeight > 0 ? '${goalWeight.toStringAsFixed(0)} kg' : 'Seleccionar', valueColor: goalWeight > 0 ? null : _accent, onTap: () => _showGoalWeightPicker(context)),
        const SizedBox(height: 10),
        _FieldRow(icon: Icons.speed, label: 'Velocidad', value: speed, onTap: () => _showSpeedSheet(context)),
      ]),
    );
  }

  void _showGoalWeightPicker(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PickerSheet(title: 'Peso objetivo', itemCount: 171, initialItem: (goalWeight.round() - 30).clamp(0, 170), itemBuilder: (i) => '${i + 30}  kg', onConfirm: (i) => onGoalWeightChanged((i + 30).toDouble())));
  }

  void _showSpeedSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _SpeedSheet(selected: speed, objective: objective, onChanged: onSpeedChanged),
    );
  }
}

// STEP 8: Name
class _NamePage extends StatelessWidget {
  final String name;
  final ValueChanged<String> onChanged;
  const _NamePage({required this.name, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(height: 60),
        _PageIcon(icon: Icons.edit),
        const SizedBox(height: 24),
        const Text('Como te llamas?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Tu nombre nos ayuda a personalizar\ntu experiencia', textAlign: TextAlign.center, style: TextStyle(color: _bodyText, fontSize: 14)),
        const SizedBox(height: 32),
        Container(
          decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _accent.withValues(alpha: 0.3))),
          child: TextField(
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
            onChanged: onChanged,
            decoration: InputDecoration(border: InputBorder.none, hintText: 'Escribe tu nombre', hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
          ),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}

// STEP 9: Summary
class _SummaryPage extends StatelessWidget {
  final int kcal; final int protein; final int carbs; final int fat; final String objective;
  const _SummaryPage({required this.kcal, required this.protein, required this.carbs, required this.fat, required this.objective});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(children: [
        const SizedBox(height: 20),
        _PageIcon(icon: Icons.auto_awesome),
        const SizedBox(height: 20),
        const Text('Tu plan esta listo', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Objetivo: $objective', style: const TextStyle(color: _bodyText, fontSize: 14)),
        const SizedBox(height: 28),
        _MacroCard(label: 'Calorias diarias', value: '$kcal', unit: 'kcal', color: const Color(0xFFEF4444)),
        const SizedBox(height: 10),
        _MacroCard(label: 'Proteina', value: '$protein', unit: 'g', color: const Color(0xFF10B981)),
        const SizedBox(height: 10),
        _MacroCard(label: 'Carbohidratos', value: '$carbs', unit: 'g', color: _accent),
        const SizedBox(height: 10),
        _MacroCard(label: 'Grasas', value: '$fat', unit: 'g', color: const Color(0xFF3B82F6)),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ==================== HELPER WIDGETS ====================

class _PageIcon extends StatelessWidget {
  final IconData icon;
  const _PageIcon({required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(shape: BoxShape.circle, color: _accent.withValues(alpha: 0.12)),
      child: Center(child: Icon(icon, color: _accent, size: 36)),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label; final String value; final String unit; final Color color;
  const _MacroCard({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900)))),
        const SizedBox(width: 14),
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600))),
        Text('$value $unit', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// Speed selection bottom sheet (Recomendado / Rapido / Lento)
/// Each option expands to show its own benefits/downsides when selected.
class _SpeedSheet extends StatefulWidget {
  final String selected;
  final String objective;
  final ValueChanged<String> onChanged;
  const _SpeedSheet({required this.selected, required this.objective, required this.onChanged});

  @override
  State<_SpeedSheet> createState() => _SpeedSheetState();
}

class _SpeedSheetState extends State<_SpeedSheet> {
  late String _chosen;

  @override
  void initState() {
    super.initState();
    _chosen = widget.selected;
  }

  String get _speedLabel {
    if (widget.objective == 'Perder Grasa') return 'Velocidad de Perdida de Peso';
    if (widget.objective == 'Ganar Musculo') return 'Velocidad de Ganancia';
    return 'Velocidad';
  }

  static const _speedData = {
    'Recomendado': {
      'emoji': '\u{1F3A7}',
      'pros': ['Gran perdida de grasa sin afectar la masa muscular', 'Resultados visibles en el corto plazo', 'Alimentacion sostenible'],
      'cons': <String>[],
    },
    'Rapido': {
      'emoji': '\u{1F3C3}',
      'pros': ['Resultados visibles en menor tiempo'],
      'cons': ['Posible ligera perdida de masa magra, debido a un mayor deficit calorico', 'Alimentacion mas restrictiva'],
    },
    'Lento': {
      'emoji': '\u{1F422}',
      'pros': ['Conservas toda tu masa muscular', 'Mas facil de mantener a largo plazo'],
      'cons': ['Resultados mas lentos, requiere mas paciencia'],
    },
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99))),
        const SizedBox(height: 16),
        Text(_speedLabel, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),

        // Speed options
        for (final entry in _speedData.entries) ...[
          _buildSpeedCard(entry.key, entry.value['emoji'] as String, entry.value['pros'] as List<String>, entry.value['cons'] as List<String>),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity, height: 52,
          child: GestureDetector(
            onTap: () {
              widget.onChanged(_chosen);
              Navigator.pop(context);
            },
            child: Container(
              decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(14)),
              child: const Center(child: Text('OK', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildSpeedCard(String label, String emoji, List<String> pros, List<String> cons) {
    final isSelected = _chosen == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _chosen = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withValues(alpha: 0.1) : _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? _accent : Colors.white.withValues(alpha: 0.06), width: isSelected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: isSelected ? _accent : Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          // Show details only when selected
          if (isSelected && (pros.isNotEmpty || cons.isNotEmpty)) ...[
            const SizedBox(height: 12),
            for (final p in pros)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13))),
                ]),
              ),
            for (final c in cons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.remove_circle, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13))),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}

// ==================== SAVING OVERLAY ====================

class _SavingOverlay extends StatefulWidget {
  final int phase; final int kcal; final int protein; final int carbs; final int fat;
  const _SavingOverlay({required this.phase, required this.kcal, required this.protein, required this.carbs, required this.fat});

  @override
  State<_SavingOverlay> createState() => _SavingOverlayState();
}

class _SavingOverlayState extends State<_SavingOverlay> with TickerProviderStateMixin {
  late AnimationController _successCtrl;
  late Animation<double> _successScale;
  late AnimationController _ambientCtrl;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _ambientCtrl = AnimationController(duration: const Duration(milliseconds: 6000), vsync: this)..repeat(reverse: true);
    _successScale = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut));
    if (widget.phase >= 3) Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _successCtrl.forward(); });
  }

  @override
  void dispose() { _ambientCtrl.dispose(); _successCtrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(_SavingOverlay old) {
    super.didUpdateWidget(old);
    if (widget.phase >= 3 && old.phase < 3) Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _successCtrl.forward(); });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ambientCtrl,
      builder: (ctx, _) {
        final t = _ambientCtrl.value;
        return Container(
          color: Colors.black.withValues(alpha: 0.95),
          child: Stack(children: [
            Positioned(top: -100 + (t * 40), left: -60, child: _Orb(size: 220 + t * 40, color: _accent)),
            Positioned(right: -80, bottom: -80 + ((1 - t) * 40), child: _Orb(size: 240 + (1 - t) * 50, color: _accentSoft)),
            Center(
              child: widget.phase >= 3
                ? ScaleTransition(scale: _successScale, child: _CompletionCard(kcal: widget.kcal, protein: widget.protein, carbs: widget.carbs, fat: widget.fat))
                : _LoadingCard(phase: widget.phase),
            ),
          ]),
        );
      },
    );
  }
}

class _Orb extends StatelessWidget {
  final double size; final Color color;
  const _Orb({required this.size, required this.color});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: 0.15), Colors.transparent]))));
  }
}

class _LoadingCard extends StatefulWidget {
  final int phase;
  const _LoadingCard({required this.phase});
  @override
  State<_LoadingCard> createState() => _LoadingCardState();
}

class _LoadingCardState extends State<_LoadingCard> with SingleTickerProviderStateMixin {
  late AnimationController _breathe;
  @override
  void initState() { super.initState(); _breathe = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(reverse: true); }
  @override
  void dispose() { _breathe.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathe,
      builder: (ctx, _) {
        final dy = math.sin(_breathe.value * math.pi * 2) * 4;
        return Transform.translate(offset: Offset(0, dy), child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Creando tu perfil', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            SizedBox(width: 72, height: 72, child: CircularProgressIndicator(value: (widget.phase + 1) / 4, strokeWidth: 5, strokeCap: StrokeCap.round, valueColor: const AlwaysStoppedAnimation(_accent), backgroundColor: const Color(0xFF2C2C2E))),
            const SizedBox(height: 20),
            _PhaseRow(label: 'Calculando objetivos', done: widget.phase >= 1),
            const SizedBox(height: 8),
            _PhaseRow(label: 'Guardando datos', done: widget.phase >= 2),
            const SizedBox(height: 8),
            _PhaseRow(label: 'Configuracion final', done: widget.phase >= 3),
          ]),
        ));
      },
    );
  }
}

class _PhaseRow extends StatelessWidget {
  final String label; final bool done;
  const _PhaseRow({required this.label, required this.done});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      AnimatedContainer(duration: const Duration(milliseconds: 300), width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, color: done ? const Color(0xFF10B981) : const Color(0xFF2C2C2E)), child: Icon(done ? Icons.check_rounded : Icons.schedule_rounded, size: 14, color: Colors.white)),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: done ? Colors.white : _bodyText, fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _CompletionCard extends StatelessWidget {
  final int kcal; final int protein; final int carbs; final int fat;
  const _CompletionCard({required this.kcal, required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24), padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_accent, _accentSoft]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: _accent.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 12))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.check_circle, size: 44, color: Colors.white)),
        const SizedBox(height: 20),
        const Text('Perfil completado!', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Tu plan nutricional esta listo', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_SM('$kcal', 'kcal'), _SM('${protein}g', 'Prot'), _SM('${carbs}g', 'Carbs'), _SM('${fat}g', 'Grasa')]),
        ),
        const SizedBox(height: 12),
        Text('Iniciando...', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
      ]),
    );
  }
}

class _SM extends StatelessWidget {
  final String v; final String l;
  const _SM(this.v, this.l);
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(v, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      Text(l, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
    ]);
  }
}
