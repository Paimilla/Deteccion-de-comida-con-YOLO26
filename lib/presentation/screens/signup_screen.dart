import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';

const Color _accent = Color(0xFF8F62FF);
const Color _accentSoft = Color(0xFF7448F0);
const Color _cardBg = Color(0xFF1A1A2E);

/// Pantalla de registro / inicio de sesión.
/// Ofrece Google Sign-In directo + formulario de email.
/// Si el usuario inicia sesión con Google y no tiene cuenta, se crea automáticamente.
class SignupScreen extends StatefulWidget {
  final AppServices services;

  const SignupScreen({super.key, required this.services});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _page = 0; // 0 = opciones, 1 = formulario de email

  // Email form
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _passVisible = false;
  bool _loading = false;
  bool _loadingGoogle = false;
  String? _errorMessage;

  late AnimationController _orbCtrl;

  @override
  void initState() {
    super.initState();
    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbCtrl.dispose();
    _pageController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _emailFormValid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _emailCtrl.text.trim().contains('@') &&
      _passCtrl.text.length >= 6;

  void _goToEmailForm() {
    HapticFeedback.lightImpact();
    setState(() {
      _page = 1;
      _errorMessage = null;
    });
    _pageController.animateToPage(1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic);
  }

  void _goBack() {
    if (_page == 1) {
      HapticFeedback.lightImpact();
      setState(() {
        _page = 0;
        _errorMessage = null;
      });
      _pageController.animateToPage(0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    } else {
      Navigator.maybePop(context);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Google Sign-In
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _continueWithGoogle() async {
    if (_loadingGoogle) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _loadingGoogle = true;
      _errorMessage = null;
    });

    try {
      final user = await widget.services.authService.signInWithGoogle();

      if (!mounted) return;

      if (user == null) {
        setState(() => _loadingGoogle = false);
        return; // Cancelado
      }

      // Track registro
      widget.services.registrationTracker.trackRegistration(
        name: user.displayName,
        email: user.email,
        provider: 'google',
        photoUrl: user.photoUrl,
      );

      // Verificar si tiene perfil nutricional
      final hasProfile = await widget.services.trackingUseCases.hasUserProfile();

      if (!mounted) return;

      if (hasProfile) {
        Navigator.pushReplacementNamed(context, AppRoutes.hoy);
      } else {
        // Ir al onboarding con nombre pre-llenado desde Google
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.onboarding,
          arguments: {'prefillName': user.displayName},
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGoogle = false;
        _errorMessage = 'Error al conectar con Google. Intenta de nuevo.';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Email Sign-Up
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _submitEmailForm() async {
    if (!_emailFormValid) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = await widget.services.authService.signUpWithEmail(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (!mounted) return;

      if (user == null) {
        setState(() {
          _loading = false;
          _errorMessage = 'No se pudo crear la cuenta. Intenta de nuevo.';
        });
        return;
      }

      // Track registro
      widget.services.registrationTracker.trackRegistration(
        name: user.displayName,
        email: user.email,
        provider: 'email',
      );

      // Verificar si ya tiene perfil
      final hasProfile = await widget.services.trackingUseCases.hasUserProfile();

      if (!mounted) return;

      if (hasProfile) {
        Navigator.pushReplacementNamed(context, AppRoutes.hoy);
      } else {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.onboarding,
          arguments: {'prefillName': user.displayName},
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Error creando cuenta: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Orbes ambientales ──
          AnimatedBuilder(
            animation: _orbCtrl,
            builder: (context, _) {
              final t = _orbCtrl.value;
              return Stack(
                children: [
                  Positioned(
                    top: -80 + (t * 30),
                    left: -40,
                    child: _Orb(size: 240, color: _accent, opacity: 0.07),
                  ),
                  Positioned(
                    bottom: -60 + ((1 - t) * 25),
                    right: -50,
                    child:
                        _Orb(size: 200, color: _accentSoft, opacity: 0.06),
                  ),
                ],
              );
            },
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _goBack,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: _cardBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _Dot(active: _page == 0),
                          const SizedBox(width: 6),
                          _Dot(active: _page == 1),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(width: 42),
                    ],
                  ),
                ),

                // ── Pages ──
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildOptionsPage(),
                      _buildEmailFormPage(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 0: Opciones (Google + Email)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildOptionsPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const Spacer(flex: 2),

          // Ícono
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withValues(alpha: 0.2),
                ),
                child: const Icon(Icons.person_add_alt_1,
                    color: _accent, size: 30),
              ),
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Únete ahora',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu cuenta para comenzar\ntu viaje nutricional',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              height: 1.4,
            ),
          ),

          const Spacer(flex: 2),

          // ── Error message ──
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Google button ──
          _GoogleButton(
            loading: _loadingGoogle,
            onTap: _continueWithGoogle,
          ),

          const SizedBox(height: 14),

          // ── Divider ──
          Row(
            children: [
              Expanded(
                child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('o',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14)),
              ),
              Expanded(
                child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Email button ──
          _SocialButton(
            icon: Icons.email_outlined,
            label: 'Continuar con correo',
            bgColor: _cardBg,
            textColor: Colors.white,
            iconColor: _accent,
            borderColor: _accent.withValues(alpha: 0.25),
            onTap: _goToEmailForm,
          ),

          const SizedBox(height: 24),

          Text(
            'Al registrarte aceptas nuestros Términos\nde uso y Política de privacidad',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAGE 1: Formulario de Email
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEmailFormPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Ícono
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: 0.1),
            ),
            child: const Center(
              child: Icon(Icons.mail_lock, color: _accent, size: 34),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Crea tu cuenta',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ingresa tus datos para registrarte',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 32),

          // ── Error message ──
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Name field ──
          _FormField(
            controller: _nameCtrl,
            icon: Icons.person_outline,
            hint: 'Nombre completo',
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 14),

          // ── Email field ──
          _FormField(
            controller: _emailCtrl,
            icon: Icons.email_outlined,
            hint: 'Correo electrónico',
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 14),

          // ── Password field ──
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: _accent.withValues(alpha: 0.15)),
            ),
            child: TextField(
              controller: _passCtrl,
              obscureText: !_passVisible,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Contraseña (mín. 6 caracteres)',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.25)),
                prefixIcon:
                    const Icon(Icons.lock_outline, color: _accent, size: 22),
                suffixIcon: GestureDetector(
                  onTap: () =>
                      setState(() => _passVisible = !_passVisible),
                  child: Icon(
                    _passVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 22,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 18),
              ),
            ),
          ),

          // ── Password strength indicator ──
          if (_passCtrl.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Row(
                children: [
                  _StrengthDot(
                      active: _passCtrl.text.isNotEmpty,
                      color: _passCtrl.text.length < 6
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  _StrengthDot(
                      active: _passCtrl.text.length >= 4,
                      color: _passCtrl.text.length < 6
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  _StrengthDot(
                      active: _passCtrl.text.length >= 6,
                      color: const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    _passCtrl.text.length < 6
                        ? 'Débil'
                        : _passCtrl.text.length < 10
                            ? 'Buena'
                            : 'Fuerte',
                    style: TextStyle(
                      color: _passCtrl.text.length < 6
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 28),

          // ── Submit button ──
          SizedBox(
            width: double.infinity,
            height: 56,
            child: GestureDetector(
              onTap: _loading ? null : _submitEmailForm,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _emailFormValid
                      ? _accent
                      : const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _emailFormValid
                      ? [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          'Crear cuenta',
                          style: TextStyle(
                            color: _emailFormValid
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Divider ──
          Row(
            children: [
              Expanded(
                child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('o regístrate rápido con',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 12)),
              ),
              Expanded(
                child: Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Google Sign-In también disponible aquí ──
          _GoogleButton(
            loading: _loadingGoogle,
            onTap: _continueWithGoogle,
          ),

          const SizedBox(height: 24),

          // ── Link a login ──
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
                children: const [
                  TextSpan(text: '¿Ya tienes cuenta? '),
                  TextSpan(
                    text: 'Inicia sesión',
                    style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widgets auxiliares
// ═══════════════════════════════════════════════════════════════════════════════

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Orb(
      {required this.size, required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: opacity), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? _accent : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _GoogleButton({required this.loading, required this.onTap});

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
                color: Colors.white.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading) ...[
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Color(0xFF4285F4)),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Conectando...',
                  style: TextStyle(
                    color: Color(0xFF5F6368),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                // Icono de Google Material
                const Icon(Icons.g_mobiledata,
                    color: Color(0xFF4285F4), size: 28),
                const SizedBox(width: 10),
                const Text(
                  'Continuar con Google',
                  style: TextStyle(
                    color: Color(0xFF3C4043),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
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

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color textColor;
  final Color iconColor;
  final Color? borderColor;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.iconColor,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: borderColor != null
              ? Border.all(color: borderColor!)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _FormField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: textCapitalization,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle:
              TextStyle(color: Colors.white.withValues(alpha: 0.25)),
          prefixIcon: Icon(icon, color: _accent, size: 22),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }
}

class _StrengthDot extends StatelessWidget {
  final bool active;
  final Color color;
  const _StrengthDot({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 32,
      height: 4,
      decoration: BoxDecoration(
        color: active ? color : const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}
