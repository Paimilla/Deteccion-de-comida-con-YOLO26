import 'dart:ui';

import 'package:flutter/material.dart';

import 'nutrifoto_ui.dart';

class AnimatedScreenBody extends StatefulWidget {
  final Widget child;

  const AnimatedScreenBody({super.key, required this.child});

  @override
  State<AnimatedScreenBody> createState() => _AnimatedScreenBodyState();
}

class _AnimatedScreenBodyState extends State<AnimatedScreenBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? const [
                        Color(0xFF0D1630),
                        NutrifotoColors.bg,
                        Color(0xFF091125),
                      ]
                    : [
                        const Color(0xFFF7F9FF),
                        theme.scaffoldBackgroundColor,
                        const Color(0xFFEFF3FF),
                      ],
              ),
            ),
          ),
        ),
        const _BackdropOrbs(),
        FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _BackdropOrbs extends StatelessWidget {
  const _BackdropOrbs();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _Orb(
              size: 220,
              color: colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -90,
            child: _Orb(
              size: 260,
              color: colorScheme.secondary.withValues(alpha: isDark ? 0.12 : 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}
