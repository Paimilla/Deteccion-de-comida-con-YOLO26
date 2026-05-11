import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_notifier.dart';
import '../widgets/nutrifoto_ui.dart';

class SettingsScreen extends StatefulWidget {
  final AppServices services;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.services,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  bool _darkMode = true;
  bool _autoCalculate = true;
  bool _expandMacros = false;
  UserProfile? _userProfile;
  NutritionGoals? _goals;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _darkMode = widget.isDarkMode;
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await widget.services.trackingUseCases.getUserProfile();
    final summary = await widget.services.trackingUseCases.getDailySummary(
      DateTime.now(),
    );

    if (!mounted) return;

    setState(() {
      _userProfile = profile;
      _goals = summary.goals;
      _kcalCtrl.text = summary.goals.kcal.toStringAsFixed(0);
      _proteinCtrl.text = summary.goals.proteinG.toStringAsFixed(0);
      _carbsCtrl.text = summary.goals.carbsG.toStringAsFixed(0);
      _fatCtrl.text = summary.goals.fatG.toStringAsFixed(0);
    });
  }

  Future<void> _saveGoals() async {
    final kcal = double.tryParse(_kcalCtrl.text.trim());
    final protein = double.tryParse(_proteinCtrl.text.trim());
    final carbs = double.tryParse(_carbsCtrl.text.trim());
    final fat = double.tryParse(_fatCtrl.text.trim());

    if (kcal == null || protein == null || carbs == null || fat == null) {
      AppNotifier.error(context, 'Revisa los valores ingresados');
      return;
    }

    await widget.services.trackingUseCases.setNutritionGoals(
      NutritionGoals(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat),
    );

    if (!mounted) return;

    setState(() {
      _goals = NutritionGoals(
        kcal: kcal,
        proteinG: protein,
        carbsG: carbs,
        fatG: fat,
      );
    });

    AppNotifier.success(context, 'Objetivos guardados');
  }

  Future<void> _saveUserProfile(UserProfile profile) async {
    await widget.services.trackingUseCases.saveUserProfile(profile);
    if (!mounted) return;
    setState(() {
      _userProfile = profile;
    });
    AppNotifier.success(context, 'Datos personales actualizados');
  }

  Future<void> _editPersonalData() async {
    final profile = _userProfile;
    if (profile == null) {
      AppNotifier.error(context, 'No hay perfil para editar');
      return;
    }

    final ageCtrl = TextEditingController(text: profile.age.toString());
    final weightCtrl = TextEditingController(
      text: profile.weightKg.toStringAsFixed(1),
    );
    final heightCtrl = TextEditingController(
      text: profile.heightCm.toStringAsFixed(0),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar datos personales'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Edad'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Peso (kg)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: heightCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Altura (cm)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) return;

    final age = int.tryParse(ageCtrl.text.trim());
    final weight = double.tryParse(weightCtrl.text.trim());
    final height = double.tryParse(heightCtrl.text.trim());

    if (age == null ||
        weight == null ||
        height == null ||
        age < 12 ||
        weight < 30 ||
        height < 120) {
      AppNotifier.error(
        context,
        'Valores invalidos. Revisa edad, peso y altura',
      );
      return;
    }

    await _saveUserProfile(
      UserProfile(
        name: profile.name,
        gender: profile.gender,
        weightKg: weight,
        heightCm: height,
        age: age,
        exercisePerWeek: profile.exercisePerWeek,
        createdAt: profile.createdAt,
      ),
    );

    if (_autoCalculate) {
      await _applyAutoGoals();
    }
  }

  Future<void> _applyAutoGoals() async {
    final profile = _userProfile;
    if (profile == null) {
      AppNotifier.error(
        context,
        'No hay perfil para calcular metas automaticas',
      );
      return;
    }

    final isMale = profile.gender.toLowerCase().startsWith('h');
    final sexAdjust = isMale ? 5.0 : -161.0;
    final bmr =
        (10 * profile.weightKg) +
        (6.25 * profile.heightCm) -
        (5 * profile.age) +
        sexAdjust;
    final activity = 1.2 + (profile.exercisePerWeek / 14.0);
    final kcal = (bmr * activity).clamp(1400.0, 4200.0).toDouble();

    final protein = (profile.weightKg * 1.9).clamp(80.0, 220.0).toDouble();
    final fat = (profile.weightKg * 0.8).clamp(45.0, 120.0).toDouble();
    final carbs = ((kcal - (protein * 4) - (fat * 9)) / 4)
        .clamp(90.0, 500.0)
        .toDouble();

    _kcalCtrl.text = kcal.toStringAsFixed(0);
    _proteinCtrl.text = protein.toStringAsFixed(0);
    _carbsCtrl.text = carbs.toStringAsFixed(0);
    _fatCtrl.text = fat.toStringAsFixed(0);

    await _saveGoals();
  }

  Future<void> _toggleAutoCalculate() async {
    if (_autoCalculate) {
      setState(() {
        _autoCalculate = false;
        _expandMacros = true;
      });
      AppNotifier.info(context, 'Modo manual activado');
      return;
    }

    setState(() {
      _autoCalculate = true;
    });
    await _applyAutoGoals();
  }

  /// Cierra la sesión pero mantiene todos los datos del usuario.
  /// Al volver a iniciar sesión con la misma cuenta, todo sigue igual.
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Se cerrará tu sesión pero tus datos y progreso se mantendrán guardados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await widget.services.authService.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.welcome,
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar cuenta'),
        content: const Text(
          '¿Estás seguro? Se eliminarán todos tus datos y tendrás que crear una nueva cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Cerrar sesión de autenticación (Google/email)
    await widget.services.authService.signOut();
    // Eliminar perfil y datos del usuario
    await widget.services.trackingUseCases.clearUserProfile();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.welcome,
      (route) => false,
    );
  }

  void _showPersonalData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datos personales'),
        content: _userProfile != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edad: ${_userProfile!.age} años'),
                  Text('Peso: ${_userProfile!.weightKg} kg'),
                  Text('Altura: ${_userProfile!.heightCm} cm'),
                ],
              )
            : const Text('Cargando datos...'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editPersonalData();
            },
            child: const Text('Editar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _openMacrosSection() {
    setState(() => _expandMacros = true);
    // Scroll hacia la sección de macros
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        AppNotifier.info(context, 'Sección de macros abierta');
      }
    });
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 370;
    final primary = Theme.of(context).colorScheme.primary;
    final sectionMutedColor = isDark ? Colors.white54 : Colors.black54;
    final subtitleMutedColor = isDark
        ? Colors.white.withValues(alpha: 0.5)
        : Colors.black54;

    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentRoute: AppRoutes.perfil),
      body: AnimatedScreenBody(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _SettingsBackdrop(animation: _ambientController),
              ),
            ),
            ListView(
              padding: EdgeInsets.only(
                top: MediaQuery.viewPaddingOf(context).top + 8,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 18,
              ),
              children: [
                const HeroPanel(
                  title: 'Configuración',
                  subtitle: 'Personaliza tu experiencia',
                  gradient: NutrifotoColors.settingsGradient,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final nextValue = !_darkMode;
                          setState(() => _darkMode = nextValue);
                          widget.onThemeChanged(nextValue);
                        },
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _darkMode
                                      ? Icons.dark_mode
                                      : Icons.light_mode,
                                  color: primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tema oscuro',
                                        style: TextStyle(
                                          fontSize: compact ? 16 : 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Cambia entre tema claro y oscuro',
                                        style: TextStyle(
                                          fontSize: compact ? 13 : 14,
                                          color: subtitleMutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _darkMode,
                                  onChanged: (value) {
                                    setState(() => _darkMode = value);
                                    widget.onThemeChanged(value);
                                  },
                                  activeThumbColor: primary,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: _openMacrosSection,
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  color: primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Objetivos Nutricionales',
                                        style: TextStyle(
                                          fontSize: compact ? 14 : 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Personaliza tus objetivos',
                                        style: TextStyle(
                                          fontSize: compact ? 12 : 13,
                                          color: sectionMutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: sectionMutedColor,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: _showPersonalData,
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  color: primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Datos personales',
                                        style: TextStyle(
                                          fontSize: compact ? 14 : 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        _userProfile != null
                                            ? '${_userProfile!.weightKg.toStringAsFixed(1)} kg • ${_userProfile!.age} años'
                                            : 'Cargando...',
                                        style: TextStyle(
                                          fontSize: compact ? 12 : 13,
                                          color: sectionMutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: sectionMutedColor,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: () =>
                            setState(() => _expandMacros = !_expandMacros),
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_note_outlined,
                                  color: primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Configurar Metas y Macros',
                                        style: TextStyle(
                                          fontSize: compact ? 14 : 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Personaliza tus objetivos',
                                        style: TextStyle(
                                          fontSize: compact ? 12 : 13,
                                          color: sectionMutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _expandMacros
                                      ? Icons.expand_less
                                      : Icons.chevron_right,
                                  color: sectionMutedColor,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_expandMacros) ...[
                        const SizedBox(height: 8),
                        GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Editar objetivos',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(_kcalCtrl, 'Calorías (kcal)'),
                                const SizedBox(height: 16),
                                _buildTextField(_proteinCtrl, 'Proteína (g)'),
                                const SizedBox(height: 16),
                                _buildTextField(
                                  _carbsCtrl,
                                  'Carbohidratos (g)',
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(_fatCtrl, 'Grasas (g)'),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _saveGoals,
                                    child: const Text('Guardar cambios'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      GestureDetector(
                        onTap: _toggleAutoCalculate,
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department_outlined,
                                  color: primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_goals?.kcal.toStringAsFixed(0) ?? '2000'} kcal por día',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${_autoCalculate ? 'Auto' : 'Manual'}-calculado',
                                        style: TextStyle(
                                          fontSize: compact ? 12 : 13,
                                          color: primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.info_outline,
                                  color: primary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Cerrar sesión (mantiene datos) ──
                      GestureDetector(
                        onTap: _signOut,
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.logout,
                                  color: primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Cerrar sesión',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Tus datos se guardan',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: subtitleMutedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: sectionMutedColor,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Eliminar perfil (borra todo) ──
                      GestureDetector(
                        onTap: _deleteAccount,
                        child: GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_forever,
                                  color: Colors.red[300],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Eliminar perfil y datos',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                      Text(
                                        'Se borrarán todos tus registros',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.red[200],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.red[300],
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 15),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

class _SettingsBackdrop extends StatelessWidget {
  final Animation<double> animation;

  const _SettingsBackdrop({required this.animation});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _SettingsBackdropPainter(
            progress: animation.value,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

class _SettingsBackdropPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _SettingsBackdropPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final centerA = Offset(size.width * 0.2, size.height * 0.25);
    final centerB = Offset(size.width * 0.84, size.height * 0.66);
    final drift = math.sin(progress * math.pi * 2) * 10;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = (isDark ? const Color(0x336D86FF) : const Color(0x227D8FE6));

    for (var i = 0; i < 4; i++) {
      canvas.drawCircle(
        centerA.translate(drift, -drift),
        44 + i * 16,
        ringPaint,
      );
      canvas.drawCircle(
        centerB.translate(-drift, drift),
        36 + i * 14,
        ringPaint,
      );
    }

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = (isDark ? const Color(0x3D8A7CFF) : const Color(0x2B8FA0DD));

    for (var i = 0; i < 26; i++) {
      final x = ((i * 39) + (progress * 110)) % (size.width + 30) - 15;
      final y = 90 + (i % 10) * 52 + math.sin(progress * 7 + i) * 5;
      canvas.drawCircle(Offset(x, y), 1.4 + (i % 3) * 0.3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SettingsBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
