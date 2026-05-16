import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
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
    colors: [Color(0xFF3E4B8D), Color(0xFF7A5EFF)],
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
      ];
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.blur = 16,
    this.opacity = 0.12,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: opacity),
              borderRadius: borderRadius ?? BorderRadius.circular(24),
              border: border ?? Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widgets Nutricionales Globales
// ═══════════════════════════════════════════════════════════════════════════════

class MacroChip extends StatelessWidget {
  final String label;
  final Color color;

  const MacroChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class FoodPlaceholder extends StatelessWidget {
  final String name;
  final double size;
  const FoodPlaceholder({super.key, required this.name, this.size = 28});

  @override
  Widget build(BuildContext context) {
    String emoji = '🍽️';
    final lower = name.toLowerCase();
    if (lower.contains('pollo') || lower.contains('chicken')) emoji = '🍗';
    if (lower.contains('arroz') || lower.contains('rice')) emoji = '🍚';
    if (lower.contains('pan') || lower.contains('bread')) emoji = '🍞';
    if (lower.contains('leche') || lower.contains('milk')) emoji = '🥛';
    if (lower.contains('huevo') || lower.contains('egg')) emoji = '🥚';
    if (lower.contains('carne') || lower.contains('meat')) emoji = '🥩';
    if (lower.contains('pescado') || lower.contains('fish')) emoji = '🐟';
    if (lower.contains('fruta') || lower.contains('manzana')) emoji = '🍎';
    if (lower.contains('queso') || lower.contains('cheese')) emoji = '🧀';
    if (lower.contains('pasta') || lower.contains('noodle')) emoji = '🍝';

    return Container(
      color: NutrifotoColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size)),
      ),
    );
  }
}

class NutrifotoImage extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final BoxFit fit;
  final String? mealTypeHint;
  final bool useOptimization;

  const NutrifotoImage({
    super.key,
    required this.imageUrl,
    required this.name,
    this.size = 28,
    this.fit = BoxFit.cover,
    this.mealTypeHint,
    this.useOptimization = true,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return FoodPlaceholder(name: name, size: size);
    }

    // Optimizar URL si es necesario
    final optimizedUrl = useOptimization
        ? _OptimizedNetworkImage(
            imageUrl: imageUrl!,
            fit: fit,
            name: name,
            mealTypeHint: mealTypeHint,
          )
        : _LegacyNetworkImage(
            imageUrl: imageUrl!,
            fit: fit,
            name: name,
          );

    return optimizedUrl;
  }
}

/// Versión optimizada con caché mejorado
class _OptimizedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final String name;
  final String? mealTypeHint;

  const _OptimizedNetworkImage({
    required this.imageUrl,
    required this.fit,
    required this.name,
    this.mealTypeHint,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final optimalWidth = _getOptimalWidth(screenWidth);

    return CachedNetworkImage(
      imageUrl: _buildOptimizedUrl(imageUrl, optimalWidth),
      fit: fit,
      memCacheHeight: (screenWidth * 1.5).toInt(),
      memCacheWidth: optimalWidth,
      maxHeightDiskCache: 800,
      maxWidthDiskCache: 800,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => FoodPlaceholder(name: name, size: 28),
    );
  }

  /// Construye URL optimizada
  String _buildOptimizedUrl(String url, int width) {
    if (url.contains('unsplash.com')) {
      if (url.contains('?')) {
        url = url.split('?').first;
      }
      return '$url?w=$width&q=80&auto=format&fit=crop';
    }
    return url;
  }

  /// Calcula ancho óptimo según pantalla
  int _getOptimalWidth(double screenWidth) {
    if (screenWidth < 400) return 300;
    if (screenWidth < 600) return 400;
    if (screenWidth < 900) return 600;
    return 800;
  }

  /// Placeholder mejorado
  Widget _buildPlaceholder() {
    return Container(
      color: NutrifotoColors.primary.withValues(alpha: 0.1),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      ),
    );
  }
}

/// Versión legado (fallback)
class _LegacyNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final String name;

  const _LegacyNetworkImage({
    required this.imageUrl,
    required this.fit,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      placeholder: (context, url) => Container(
        color: NutrifotoColors.primary.withValues(alpha: 0.1),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => FoodPlaceholder(name: name, size: 28),
    );
  }
}

class LoadingBlock extends StatefulWidget {
  final String message;
  const LoadingBlock({super.key, this.message = 'Cargando...'});

  @override
  State<LoadingBlock> createState() => _LoadingBlockState();
}

class _LoadingBlockState extends State<LoadingBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: NutrifotoColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
    final highlightColor =
        isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.1);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _ShimmerBox(
          width: widget.width ?? double.infinity,
          height: widget.height,
          borderRadius: widget.borderRadius,
          progress: _controller.value,
          baseColor: baseColor,
          highlightColor: highlightColor,
        );
      },
    );
  }
}

class SkeletonCard extends StatefulWidget {
  const SkeletonCard({super.key});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
    final highlightColor = isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.1);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: NutrifotoColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              _ShimmerBox(
                width: 52,
                height: 52,
                borderRadius: 12,
                progress: _controller.value,
                baseColor: baseColor,
                highlightColor: highlightColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(
                      width: 140,
                      height: 14,
                      progress: _controller.value,
                      baseColor: baseColor,
                      highlightColor: highlightColor,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ShimmerBox(
                          width: 50,
                          height: 18,
                          borderRadius: 6,
                          progress: _controller.value,
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                        ),
                        const SizedBox(width: 6),
                        _ShimmerBox(
                          width: 40,
                          height: 18,
                          borderRadius: 6,
                          progress: _controller.value,
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final double progress;
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 4,
    required this.progress,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [baseColor, highlightColor, baseColor],
          stops: [
            (progress - 0.3).clamp(0.0, 1.0),
            progress.clamp(0.0, 1.0),
            (progress + 0.3).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
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
