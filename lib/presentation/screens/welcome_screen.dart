import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/nutrifoto_ui.dart';

/// Pantalla de bienvenida con opciones de autenticación:
///  • Google Sign-In (1 tap)
///  • Crear cuenta (onboarding completo)
///  • Iniciar sesión (email/password)
///  • Modo Invitado (reclutadores — solo nombre + fuente)
class WelcomeScreen extends StatefulWidget {
  final AppServices services;

  const WelcomeScreen({super.key, required this.services});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _orbController;
  late Animation<double> _logoScale;
  late Animation<double> _contentFade;
  bool _loadingGoogle = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Google Sign-In
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleGoogleSignIn() async {
    if (_loadingGoogle) return;
    HapticFeedback.mediumImpact();

    setState(() => _loadingGoogle = true);

    try {
      final user = await widget.services.authService.signInWithGoogle();

      if (!mounted) return;

      if (user == null) {
        setState(() => _loadingGoogle = false);
        return;
      }

      // Track registro
      widget.services.registrationTracker.trackRegistration(
        name: user.displayName,
        email: user.email,
        provider: 'google',
        photoUrl: user.photoUrl,
      );

      // Verificar si ya tiene perfil nutricional
      bool hasProfile = await widget.services.trackingUseCases.hasUserProfile();

      if (!mounted) return;

      if (!hasProfile) {
        // PARCHE: Si entra con Google, inicializamos un perfil básico para evitar el bloqueo del onboarding
        // El usuario podrá editar estos datos luego en Settings.
        await widget.services.trackingUseCases.setNutritionGoals(const NutritionGoals(
          kcal: 2000,
          proteinG: 120,
          carbsG: 230,
          fatG: 60,
        ));

        await widget.services.trackingUseCases.saveUserProfile(UserProfile(
          name: user.displayName,
          gender: 'No especificado',
          weightKg: 70,
          heightCm: 170,
          age: 30,
          exercisePerWeek: 3,
          createdAt: DateTime.now(),
        ));
        
        hasProfile = true;
      }

      if (hasProfile && mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.hoy);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingGoogle = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error al iniciar sesión: $e',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Modo Invitado
  // ═══════════════════════════════════════════════════════════════════════════

  void _showGuestSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GuestModeSheet(
        onSubmit: (name, source) async {
          Navigator.pop(ctx);

          // Mostrar overlay de carga premium
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: NutrifotoColors.primary),
                    SizedBox(height: 16),
                    Text(
                      'Preparando tu perfil...',
                      style: TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none),
                    ),
                  ],
                ),
              ),
            ),
          );

          // Crear sesión de invitado
          await widget.services.authService.signInAsGuest(
            name: name,
            source: source,
          );

          // Track visita de invitado en Google Sheets (webhook)
          await widget.services.registrationTracker.trackGuestVisit(
            name: name,
            source: source,
          );

          if (!mounted) return;

          // Inicializar perfil predeterminado
          final hasProfile = await widget.services.trackingUseCases.hasUserProfile();
          if (!hasProfile) {
            await widget.services.trackingUseCases.setNutritionGoals(const NutritionGoals(
              kcal: 2200,
              proteinG: 140,
              carbsG: 260,
              fatG: 65,
            ));

            await widget.services.trackingUseCases.saveUserProfile(UserProfile(
              name: name,
              gender: 'Hombre',
              weightKg: 75,
              heightCm: 175,
              age: 28,
              exercisePerWeek: 3,
              createdAt: DateTime.now(),
            ));
          }

          if (!mounted) return;

          // Quitar el loading
          Navigator.pop(context);

          // Ir directamente al Main
          Navigator.pushReplacementNamed(context, AppRoutes.hoy);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Orbes de fondo ambientales ──
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, _) {
              final t = _orbController.value;
              return Stack(
                children: [
                  Positioned(
                    top: -120 + (t * 50),
                    right: -80,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          NutrifotoColors.primary.withValues(alpha: 0.1),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100 + ((1 - t) * 40),
                    left: -60,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          NutrifotoColors.primarySoft.withValues(alpha: 0.08),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Contenido principal ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // ── Logo con animación ──
                  ScaleTransition(
                    scale: _logoScale,
                    child: Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                NutrifotoColors.primary.withValues(alpha: 0.25),
                                NutrifotoColors.primary.withValues(alpha: 0.05),
                              ],
                              radius: 0.8,
                            ),
                            border: Border.all(
                              color: NutrifotoColors.primary.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo_cat_strawberry.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, e, s) =>
                                  const Icon(Icons.restaurant_menu,
                                      color: NutrifotoColors.primary, size: 48),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Nutrifoto',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tu asistente nutricional\ncon inteligencia artificial',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Botones ──
                  FadeTransition(
                    opacity: _contentFade,
                    child: Column(
                      children: [
                        // ── Google Sign-In ──
                        _GoogleSignInButton(
                          loading: _loadingGoogle,
                          onTap: _handleGoogleSignIn,
                        ),

                        const SizedBox(height: 12),

                        // ── Crear cuenta ──
                        _ActionButton(
                          label: 'Crear cuenta',
                          gradient: const LinearGradient(
                            colors: [
                              NutrifotoColors.primary,
                              NutrifotoColors.primarySoft,
                            ],
                          ),
                          textColor: Colors.white,
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pushNamed(context, AppRoutes.onboarding);
                          },
                        ),

                        const SizedBox(height: 12),

                        // ── Iniciar sesión ──
                        _ActionButton(
                          label: 'Iniciar sesión',
                          bgColor: const Color(0xFF1A1A2E),
                          textColor: Colors.white.withValues(alpha: 0.9),
                          borderColor: NutrifotoColors.primary.withValues(alpha: 0.2),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pushNamed(context, AppRoutes.signup);
                          },
                        ),

                        const SizedBox(height: 16),

                        // ── Divider ──
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                '¿Solo quieres probar?',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                  height: 1,
                                  color: Colors.white.withValues(alpha: 0.08)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // ── Modo Invitado ──
                        GestureDetector(
                          onTap: _showGuestSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.explore_outlined,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  'Entrar como invitado',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Texto legal ──
                        Text(
                          'Al continuar aceptas nuestros Términos de uso\ny Política de privacidad',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Botón de Google Sign-In (estilo oficial)
// ═══════════════════════════════════════════════════════════════════════════════

class _GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _GoogleSignInButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF4285F4)),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Conectando...',
                  style: TextStyle(
                    color: Color(0xFF5F6368), fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: 24, height: 24,
                  child: CustomPaint(painter: _GoogleLogoPainter()),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Continuar con Google',
                  style: TextStyle(
                    color: Color(0xFF3C4043), fontSize: 16,
                    fontWeight: FontWeight.w600, letterSpacing: 0.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Botón genérico de acción
// ═══════════════════════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  final String label;
  final Gradient? gradient;
  final Color? bgColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    this.gradient,
    this.bgColor,
    required this.textColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? bgColor : null,
            borderRadius: BorderRadius.circular(16),
            border: borderColor != null ? Border.all(color: borderColor!) : null,
            boxShadow: gradient != null
                ? [
                    BoxShadow(
                      color: NutrifotoColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Bottom Sheet de Modo Invitado
// ═══════════════════════════════════════════════════════════════════════════════

class _GuestModeSheet extends StatefulWidget {
  final Future<void> Function(String name, String source) onSubmit;

  const _GuestModeSheet({required this.onSubmit});

  @override
  State<_GuestModeSheet> createState() => _GuestModeSheetState();
}

class _GuestModeSheetState extends State<_GuestModeSheet> {
  final _nameCtrl = TextEditingController();
  String _selectedSource = '';
  bool _submitting = false;

  static const _sources = [
    '🔗 LinkedIn',
    '💼 GitHub',
    '🐦 Twitter / X',
    '📸 Instagram',
    '👥 Referido',
    '🌐 Búsqueda web',
    '📋 Portfolio',
    '🎯 Otro',
  ];

  bool get _isValid =>
      _nameCtrl.text.trim().isNotEmpty && _selectedSource.isNotEmpty;

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() => _submitting = true);
    await widget.onSubmit(_nameCtrl.text.trim(), _selectedSource);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141428),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: NutrifotoColors.primary.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.waving_hand,
                      color: NutrifotoColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo Invitado',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Explora la app sin crear cuenta',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Name field
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: NutrifotoColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '¿Cómo te llamas?',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                  prefixIcon: const Icon(Icons.person_outline,
                      color: NutrifotoColors.primary, size: 22),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Source question
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '¿Cómo me conociste?',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Source chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sources.map((source) {
                final isSelected = _selectedSource == source;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSource = source);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? NutrifotoColors.primary.withValues(alpha: 0.15)
                          : const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? NutrifotoColors.primary
                            : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      source,
                      style: TextStyle(
                        color: isSelected
                            ? NutrifotoColors.primary
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: GestureDetector(
                onTap: _submit,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: _isValid
                        ? NutrifotoColors.primary
                        : const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _isValid
                        ? [
                            BoxShadow(
                              color: NutrifotoColors.primary
                                  .withValues(alpha: 0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _submitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.rocket_launch,
                                  color: _isValid
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                  size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Explorar Nutrifoto',
                                style: TextStyle(
                                  color: _isValid
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.3),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Google Logo Painter (4 colores oficiales)
// ═══════════════════════════════════════════════════════════════════════════════

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double r = w * 0.45;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.18
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -0.4, 1.2, false, paint,
    );

    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0.8, 1.2, false, paint,
    );

    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      2.0, 1.0, false, paint,
    );

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      3.0, 1.2, false, paint,
    );

    paint
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = w * 0.15
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.9, cy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
