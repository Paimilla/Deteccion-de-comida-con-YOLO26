import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../domain/models/tracking_models.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/nutrifoto_ui.dart';

class AssistantScreen extends StatefulWidget {
  final AppServices services;

  const AssistantScreen({super.key, required this.services});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen>
    with SingleTickerProviderStateMixin {
  final _inputCtrl = TextEditingController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final _topics = const ['General', 'Nutricion', 'Fitness'];
  final _scrollCtrl = ScrollController();
  late final AnimationController _ambientController;
  bool _hasInput = false;
  int _selectedTopic = 0;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _inputCtrl.addListener(_onInputChanged);
    _messages.add(
      const _ChatMessage(
        role: _Role.assistant,
        text: 'Hola, soy tu asistente. Preguntame por tu progreso de hoy.',
      ),
    );
  }

  void _onInputChanged() {
    final hasText = _inputCtrl.text.trim().isNotEmpty;
    if (hasText != _hasInput) {
      setState(() => _hasInput = hasText);
    }
  }

  @override
  void dispose() {
    _inputCtrl.removeListener(_onInputChanged);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final input = _inputCtrl.text.trim();
    if (input.isEmpty) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(role: _Role.user, text: input));
      _inputCtrl.clear();
    });
    _scrollToBottom();

    final summary = await widget.services.trackingUseCases.getDailySummary(
      DateTime.now(),
    );

    final answer = _buildAnswer(input, summary);
    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(role: _Role.assistant, text: answer));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) {
        return;
      }
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _buildAnswer(String input, DailySummary summary) {
    final lower = input.toLowerCase();
    final kcal = summary.kcalTotal;
    final goal = summary.goals.kcal;
    final water = summary.hydrationMl;

    if (lower.contains('hoy') || lower.contains('progreso')) {
      final pct = goal <= 0 ? 0 : ((kcal / goal) * 100).clamp(0, 999);
      return 'Hoy llevas ${kcal.toStringAsFixed(0)} kcal de ${goal.toStringAsFixed(0)} kcal (${pct.toStringAsFixed(0)}%). Hidratacion: $water ml.';
    }

    if (lower.contains('agua') || lower.contains('hidrat')) {
      return 'Tu hidratacion actual es de $water ml. Si quieres, agrega 250 ml desde el modulo Hidratacion.';
    }

    if (lower.contains('macro') || lower.contains('prote')) {
      return 'Macros de hoy: P ${summary.proteinTotal.toStringAsFixed(1)} g, C ${summary.carbsTotal.toStringAsFixed(1)} g, G ${summary.fatTotal.toStringAsFixed(1)} g.';
    }

    return 'Puedo ayudarte con progreso diario, hidratacion y macros. Prueba: "como voy hoy".';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 370;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardInset > 0;
    final inactiveChipBg = isDark
        ? NutrifotoColors.surface
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final composerBg = isDark
        ? const Color(0xCC1A2743)
        : Colors.white.withValues(alpha: 0.92);

    return Scaffold(
      appBar: AppBar(title: const Text('Asistente IA')),
      bottomNavigationBar: keyboardOpen
          ? null
          : const AppBottomNav(currentRoute: AppRoutes.assistant),
      body: AnimatedScreenBody(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _AssistantBackdrop(animation: _ambientController),
              ),
            ),
            Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: keyboardOpen
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                          child: HeroPanel(
                            title: 'Asistente de IA',
                            subtitle: 'Analisis contextual en tiempo real',
                            gradient: NutrifotoColors.assistantGradient,
                            trailing: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: keyboardOpen
                      ? const SizedBox.shrink()
                      : SizedBox(
                          height: 44,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, index) {
                              final topic = _topics[index];
                              final selected = _selectedTopic == index;

                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedTopic = index),
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 220),
                                  scale: selected ? 1.02 : 1,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? NutrifotoColors.primary.withValues(
                                              alpha: 0.35,
                                            )
                                          : inactiveChipBg,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected
                                            ? NutrifotoColors.primary
                                                  .withValues(alpha: 0.7)
                                            : Colors.transparent,
                                      ),
                                      boxShadow: selected
                                          ? [
                                              BoxShadow(
                                                color: NutrifotoColors.primary
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 14,
                                                offset: const Offset(0, 6),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Text(
                                      topic,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            separatorBuilder: (_, index) =>
                                const SizedBox(width: 8),
                            itemCount: _topics.length,
                          ),
                        ),
                ),
                SizedBox(height: keyboardOpen ? 2 : 10),
                Expanded(
                  child: ListView.separated(
                    controller: _scrollCtrl,
                    padding: EdgeInsets.fromLTRB(12, 2, 12, compact ? 10 : 14),
                    itemCount: _messages.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg.role == _Role.user;

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 18),
                              child: child,
                            ),
                          );
                        },
                        child: _MessageBubble(
                          text: msg.text,
                          isUser: isUser,
                          isDark: isDark,
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  margin: EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    keyboardOpen ? (compact ? 8 : 10) : (compact ? 8 : 12),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: composerBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.25 : 0.08,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                            hintText: 'Escribe tu mensaje...',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ),
                      AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        scale: _hasInput ? 1.0 : 0.92,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _hasInput ? 1.0 : 0.65,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6F5CFF), Color(0xFF8F62FF)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: IconButton(
                              onPressed: _send,
                              icon: const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
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
}

enum _Role { user, assistant }

class _ChatMessage {
  final _Role role;
  final String text;

  const _ChatMessage({required this.role, required this.text});
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isDark;

  const _MessageBubble({
    required this.text,
    required this.isUser,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final assistantBg = isDark
        ? NutrifotoColors.surface
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3E4B8D), Color(0xFF7A5EFF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
              decoration: BoxDecoration(
                color: isUser
                    ? NutrifotoColors.primary.withValues(alpha: 0.38)
                    : assistantBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isUser
                      ? NutrifotoColors.primary.withValues(alpha: 0.55)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08)),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantBackdrop extends StatelessWidget {
  final Animation<double> animation;

  const _AssistantBackdrop({required this.animation});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final driftA = math.sin(t * math.pi * 2) * 18;
        final driftB = math.cos(t * math.pi * 2) * 16;

        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0x22121E44), Color(0x080A1228)]
                        : const [Color(0x1A9AB8FF), Color(0x0696A9FF)],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _AssistantWavePainter(progress: t, isDark: isDark),
              ),
            ),
            Positioned(
              top: -110 + driftA,
              right: -60 + driftB,
              child: _GlowOrb(
                size: 240,
                color: isDark
                    ? const Color(0x2A7B62FF)
                    : const Color(0x2286C5FF),
              ),
            ),
            Positioned(
              top: 190 + driftB,
              left: -120 + driftA,
              child: _GlowOrb(
                size: 210,
                color: isDark
                    ? const Color(0x244E57D6)
                    : const Color(0x1C69D5D0),
              ),
            ),
            Positioned(
              bottom: -130 + driftA,
              right: -90 + driftB,
              child: _GlowOrb(
                size: 260,
                color: isDark
                    ? const Color(0x1F6F4EFF)
                    : const Color(0x166BC8EA),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.38, 1],
        ),
      ),
    );
  }
}

class _AssistantWavePainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _AssistantWavePainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final baseY = size.height * 0.62;
    final amp = 10 + (math.sin(progress * math.pi * 2) * 3);

    for (var i = 0; i < 4; i++) {
      final path = Path();
      final yOffset = i * 22.0;
      path.moveTo(-20, baseY + yOffset);
      for (double x = -20; x <= size.width + 20; x += 16) {
        final y = baseY + yOffset + math.sin((x / 90) + progress * 6 + i) * amp;
        path.lineTo(x, y);
      }

      final color = (isDark ? const Color(0x338FAEFF) : const Color(0x2293B7FF))
          .withValues(alpha: 0.22 - i * 0.04);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawPath(path, paint);
    }

    final dotPaint = Paint()
      ..color = (isDark ? const Color(0x338FD8FF) : const Color(0x1F5CBCE2))
      ..style = PaintingStyle.fill;
    for (var i = 0; i < 18; i++) {
      final x = (i * 47.0 + progress * 120) % (size.width + 40) - 20;
      final y = baseY - 120 + (i % 5) * 22 + math.sin(progress * 5 + i) * 3;
      canvas.drawCircle(Offset(x, y), 1.3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AssistantWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
