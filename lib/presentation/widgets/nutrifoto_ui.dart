import 'package:flutter/material.dart';

class NutrifotoColors {
  static const bg = Color(0xFF080F2A);
  static const surface = Color(0xFF1A2743);
  static const surfaceSoft = Color(0xFF24365A);
  static const primary = Color(0xFF8F62FF);
  static const primarySoft = Color(0xFF7448F0);
  static const accentBlue = Color(0xFF53B8FF);
  static const textMuted = Color(0xFFB1B8CF);

  // Colores vibrantes para secciones
  static const desayunoGradient = LinearGradient(
    colors: [Color(0xFFFFA726), Color(0xFFFF7043)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const almuerzoGradient = LinearGradient(
    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cenaGradient = LinearGradient(
    colors: [Color(0xFF5C6BC0), Color(0xFF3F51B5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const onceGradient = LinearGradient(
    colors: [Color(0xFFAB47BC), Color(0xFF8E24AA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const snackGradient = LinearGradient(
    colors: [Color(0xFFFF6E40), Color(0xFFD84315)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Enhanced hero gradient with deeper stop distribution
  static const heroGradient = LinearGradient(
    colors: [Color(0xFF141B3D), Color(0xFF3A22A0), Color(0xFF8C5BFF)],
    stops: [0.0, 0.45, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const hydrationGradient = LinearGradient(
    colors: [Color(0xFF1A3B62), Color(0xFF19B7DF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const assistantGradient = LinearGradient(
    colors: [Color(0xFF1A2040), Color(0xFF4A28B8), Color(0xFF8C5BFF)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const searchGradient = LinearGradient(
    colors: [Color(0xFF1B2449), Color(0xFF5C3DCE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const scannerGradient = LinearGradient(
    colors: [Color(0xFF171E3D), Color(0xFF3E2E84), Color(0xFF6E47E6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const settingsGradient = LinearGradient(
    colors: [Color(0xFF5A35C8), Color(0xFF8C5BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Goal completed celebration gradient
  static const goalCompletedGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Enhanced elevated shadow for floating elements
  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: primary.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ];
}

class HeroPanel extends StatefulWidget {
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final Widget? trailing;

  const HeroPanel({
    super.key,
    required this.title,
    required this.subtitle,
    this.gradient = NutrifotoColors.heroGradient,
    this.trailing,
  });

  @override
  State<HeroPanel> createState() => _HeroPanelState();
}

class _HeroPanelState extends State<HeroPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 380;
    final stacked = width < 360; // Material Design small device breakpoint

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          padding: EdgeInsets.all(compact ? 14 : 18),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: compact ? 24 : 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: const Color(0xFFD9E0F5),
                        fontSize: compact ? 13 : 14,
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: widget.trailing!,
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: compact ? 24 : 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle,
                            style: TextStyle(
                              color: const Color(0xFFD9E0F5),
                              fontSize: compact ? 13 : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 8),
                      widget.trailing!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool animate;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xDD1A2743)
            : theme.colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.7),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );

    return card;
  }
}

/// Card con colores personalizados y gradientes
class GradientCard extends StatelessWidget {
  final Widget child;
  final LinearGradient gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final bool animate;

  const GradientCard({
    super.key,
    required this.child,
    required this.gradient,
    this.padding,
    this.margin,
    this.borderRadius,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(24);

    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: br,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: child,
    );

    return card;
  }
}

/// Button animado con efecto de presión
class AnimatedButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final LinearGradient? gradient;
  final bool fullWidth;
  final Widget? icon;
  final bool loading;

  const AnimatedButton({
    super.key,
    required this.label,
    required this.onTap,
    this.backgroundColor,
    this.gradient,
    this.fullWidth = false,
    this.icon,
    this.loading = false,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuad),
    );

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.8,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Widget button;

    if (widget.gradient != null) {
      button = Container(
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: widget.loading ? null : widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: _buildContent(),
            ),
          ),
        ),
      );
    } else {
      button = Material(
        color: widget.backgroundColor ?? NutrifotoColors.primary,
        borderRadius: BorderRadius.circular(16),
        elevation: 8,
        shadowColor: (widget.backgroundColor ?? NutrifotoColors.primary)
            .withValues(alpha: 0.4),
        child: InkWell(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: widget.loading ? null : widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: _buildContent(),
          ),
        ),
      );
    }

    final scaled = ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(opacity: _opacityAnimation, child: button),
    );

    if (widget.fullWidth) {
      return SizedBox(width: double.infinity, child: scaled);
    }
    return scaled;
  }

  Widget _buildContent() {
    if (widget.loading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.icon!,
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      );
    }

    return Text(
      widget.label,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: Colors.white,
      ),
    );
  }
}
