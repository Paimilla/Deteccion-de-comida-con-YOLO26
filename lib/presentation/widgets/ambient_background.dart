import 'dart:math' as math;
import 'package:flutter/material.dart';

class AmbientBackground extends StatefulWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
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
    
    return Stack(
      children: [
        // Base Background
        Container(
          color: isDark ? const Color(0xFF080F2A) : const Color(0xFFF8FAFC),
        ),
        
        // Animated Blobs
        if (isDark)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Stack(
                children: [
                  _PositionedBlob(
                    controller: _controller,
                    color: const Color(0xFF1E293B),
                    baseOffset: const Offset(-0.2, 0.1),
                    radius: 400,
                    speed: 1.0,
                  ),
                  _PositionedBlob(
                    controller: _controller,
                    color: const Color(0xFF312E81).withValues(alpha: 0.3),
                    baseOffset: const Offset(0.8, 0.7),
                    radius: 500,
                    speed: 0.8,
                  ),
                  _PositionedBlob(
                    controller: _controller,
                    color: const Color(0xFF4C1D95).withValues(alpha: 0.2),
                    baseOffset: const Offset(0.3, 0.9),
                    radius: 350,
                    speed: 1.2,
                  ),
                ],
              );
            },
          ),
        
        // Main Content
        widget.child,
      ],
    );
  }
}

class _PositionedBlob extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final Offset baseOffset;
  final double radius;
  final double speed;

  const _PositionedBlob({
    required this.controller,
    required this.color,
    required this.baseOffset,
    required this.radius,
    required this.speed,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final angle = controller.value * 2 * math.pi * speed;
    
    final x = baseOffset.dx * size.width + math.cos(angle) * 30;
    final y = baseOffset.dy * size.height + math.sin(angle) * 30;

    return Positioned(
      left: x - radius / 2,
      top: y - radius / 2,
      child: Container(
        width: radius,
        height: radius,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
