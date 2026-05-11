import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/app_routes.dart';
import '../../application/app_services.dart';
import '../../infrastructure/services/hydration_reminder_service.dart';
import '../widgets/animated_screen_body.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/app_notifier.dart';
import '../widgets/nutrifoto_ui.dart';

class HydrationScreen extends StatefulWidget {
  final AppServices services;

  const HydrationScreen({super.key, required this.services});

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen>
    with TickerProviderStateMixin {
  int _todayMl = 0;
  final _goalMl = 2800;
  bool _reminders = false;
  bool _reminderSettingsLoading = true;
  bool _reminderPluginAvailable = true;
  HydrationReminderSettings _reminderSettings =
      const HydrationReminderSettings.defaults();
  bool _wasHydrationComplete = false;
  bool _showCelebration = false;
  Timer? _celebrationTimer;
  late final AnimationController _celebrationController;
  late final AnimationController _ambientController;

  int get _cupsDone => (_todayMl / 250).floor();
  int get _cupsGoal => (_goalMl / 250).ceil();

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
    _load();
    _loadReminderSettings();
  }

  Future<void> _loadReminderSettings() async {
    await HydrationReminderService.instance.initialize();
    final settings = await HydrationReminderService.instance.loadSettings();
    final available = HydrationReminderService.instance.isPluginAvailable;
    if (!mounted) {
      return;
    }
    setState(() {
      _reminderSettings = settings;
      _reminders = settings.enabled && available;
      _reminderPluginAvailable = available;
      _reminderSettingsLoading = false;
    });

    if (!available && mounted) {
      AppNotifier.info(
        context,
        'Las notificaciones no estan disponibles en esta ejecucion.',
      );
    }
  }

  Future<void> _load() async {
    final summary = await widget.services.trackingUseCases.getDailySummary(
      DateTime.now(),
    );
    if (!mounted) {
      return;
    }

    final isNowComplete = summary.hydrationMl >= _goalMl;
    setState(() => _todayMl = summary.hydrationMl);

    if (isNowComplete && !_wasHydrationComplete) {
      _triggerCompletionCelebration();
    }
    _wasHydrationComplete = isNowComplete;
  }

  Future<void> _add(int ml) async {
    await widget.services.trackingUseCases.addHydrationMl(ml);
    await _load();
    if (!mounted) {
      return;
    }
    AppNotifier.success(context, 'Agregaste ${ml}ml de agua');
  }

  Future<void> _updateReminderSettings(
    HydrationReminderSettings next, {
    bool requestPermission = false,
  }) async {
    if (next.enabled && !_reminderPluginAvailable) {
      AppNotifier.error(
        context,
        'No fue posible activar recordatorios en este dispositivo/sesion.',
      );
      return;
    }

    if (requestPermission && next.enabled) {
      final permissionOk = await HydrationReminderService.instance
          .requestPermissionsIfNeeded();
      if (!permissionOk) {
        if (!mounted) return;
        setState(() {
          _reminderPluginAvailable = false;
          _reminders = false;
          _reminderSettings = _reminderSettings.copyWith(enabled: false);
        });
        AppNotifier.error(
          context,
          'No se pudieron inicializar las notificaciones. Reinicia la app completa.',
        );
        return;
      }
    }

    final saved = await HydrationReminderService.instance.saveSettings(next);
    if (!mounted) {
      return;
    }

    if (!saved && next.enabled) {
      setState(() {
        _reminderPluginAvailable = false;
        _reminders = false;
        _reminderSettings = next.copyWith(enabled: false);
      });
      AppNotifier.error(
        context,
        'No se pudo programar recordatorios. Reinicia la app completa.',
      );
      return;
    }

    setState(() {
      _reminderPluginAvailable =
          HydrationReminderService.instance.isPluginAvailable;
      _reminderSettings = next;
      _reminders = next.enabled;
    });

    final msg = next.enabled
        ? 'Recordatorios activados: ${next.summary}'
        : 'Recordatorios desactivados';
    AppNotifier.success(context, msg);
  }

  Future<void> _openReminderSetup() async {
    if (_reminderSettingsLoading) {
      return;
    }

    var draft = _reminderSettings;
    final result = await showModalBottomSheet<HydrationReminderSettings>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickStart() async {
              final initial = TimeOfDay(
                hour: draft.startHour,
                minute: draft.startMinute,
              );
              final picked = await showTimePicker(
                context: context,
                initialTime: initial,
              );
              if (picked == null) return;
              setSheetState(() {
                draft = draft.copyWith(
                  startHour: picked.hour,
                  startMinute: picked.minute,
                );
              });
            }

            Future<void> pickEnd() async {
              final initial = TimeOfDay(
                hour: draft.endHour,
                minute: draft.endMinute,
              );
              final picked = await showTimePicker(
                context: context,
                initialTime: initial,
              );
              if (picked == null) return;
              setSheetState(() {
                draft = draft.copyWith(
                  endHour: picked.hour,
                  endMinute: picked.minute,
                );
              });
            }

            final insets = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insets),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configurar recordatorios',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: draft.enabled,
                    onChanged: (value) => setSheetState(
                      () => draft = draft.copyWith(enabled: value),
                    ),
                    title: const Text('Activar notificaciones'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: const Text('Hora de inicio'),
                    subtitle: Text(
                      _formatClock(draft.startHour, draft.startMinute),
                    ),
                    onTap: pickStart,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Hora de fin'),
                    subtitle: Text(
                      _formatClock(draft.endHour, draft.endMinute),
                    ),
                    onTap: pickEnd,
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: draft.intervalMinutes,
                    decoration: const InputDecoration(
                      labelText: 'Intervalo de recordatorio',
                    ),
                    items: const [30, 45, 60, 90, 120, 180]
                        .map(
                          (m) => DropdownMenuItem<int>(
                            value: m,
                            child: Text('Cada $m minutos'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        draft = draft.copyWith(intervalMinutes: value);
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar configuracion'),
                      onPressed: () => Navigator.of(context).pop(draft),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }
    await _updateReminderSettings(result, requestPermission: result.enabled);
  }

  String _formatClock(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _triggerCompletionCelebration() {
    _celebrationTimer?.cancel();

    if (mounted) {
      setState(() => _showCelebration = true);
    }

    _celebrationController.forward(from: 0);
    AppNotifier.success(context, 'Meta de hidratacion completada. Excelente!');

    _celebrationTimer = Timer(const Duration(milliseconds: 2100), () {
      if (!mounted) {
        return;
      }
      setState(() => _showCelebration = false);
    });
  }

  @override
  void dispose() {
    _celebrationTimer?.cancel();
    _ambientController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;
    final pct = (_todayMl / _goalMl).clamp(0, 1).toDouble();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionTitleColor = isDark ? Colors.white : const Color(0xFF1F2A4A);

    return Scaffold(
      appBar: AppBar(title: const Text('Hidratacion')),
      bottomNavigationBar: const AppBottomNav(
        currentRoute: AppRoutes.hydration,
      ),
      body: AnimatedScreenBody(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _HydrationBackdrop(animation: _ambientController),
              ),
            ),
            if (_showCelebration)
              Positioned.fill(
                child: IgnorePointer(
                  child: _HydrationCelebrationOverlay(
                    animation: _celebrationController,
                  ),
                ),
              ),
            ListView(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              children: [
                HeroPanel(
                  title: 'Hidratacion',
                  subtitle: 'Mantente hidratado durante el dia',
                  gradient: NutrifotoColors.hydrationGradient,
                  trailing: _HydrationStatusBadge(
                    percent: (pct * 100).toStringAsFixed(0),
                  ),
                ),
                const SizedBox(height: 12),
                GradientCard(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0FA8D0), Color(0xFF17C0E9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: (_todayMl / 1000).toStringAsFixed(1),
                              style: TextStyle(
                                fontSize: isCompact ? 34 : 42,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            TextSpan(
                              text:
                                  ' / ${(_goalMl / 1000).toStringAsFixed(1)} L',
                              style: TextStyle(
                                fontSize: isCompact ? 18 : 22,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDDF7FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$_cupsDone de $_cupsGoal vasos',
                        style: const TextStyle(
                          color: Color(0xFFDDF7FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 9,
                          backgroundColor: Colors.white.withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Agregar agua',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: isCompact ? 16 : 18,
                    color: sectionTitleColor,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 700
                        ? 4
                        : constraints.maxWidth >= 500
                        ? 3
                        : 2;
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: columns >= 3 ? 1.1 : 1.35,
                      children: [
                        _HydrationTile(
                          label: '1 vaso',
                          amount: '250 ml',
                          icon: Icons.water_drop,
                          onTap: () => _add(250),
                        ),
                        _HydrationTile(
                          label: '2 vasos',
                          amount: '500 ml',
                          icon: Icons.opacity,
                          onTap: () => _add(500),
                        ),
                        _HydrationTile(
                          label: 'Botella',
                          amount: '750 ml',
                          icon: Icons.local_drink,
                          onTap: () => _add(750),
                        ),
                        _HydrationTile(
                          label: 'Litro',
                          amount: '1000 ml',
                          icon: Icons.inventory_2,
                          onTap: () => _add(1000),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                GlassCard(
                  child: _reminderSettingsLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: NutrifotoColors.primary.withValues(
                                    alpha: 0.16,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_active_outlined,
                                  color: NutrifotoColors.primary,
                                  size: 21,
                                ),
                              ),
                              title: const Text(
                                'Recordatorios de hidratacion',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                !_reminderPluginAvailable
                                    ? 'No disponible en esta sesion'
                                    : _reminders
                                    ? _reminderSettings.summary
                                    : 'Desactivados',
                              ),
                              trailing: Switch(
                                value: _reminders && _reminderPluginAvailable,
                                onChanged: (value) async {
                                  if (!_reminderPluginAvailable && value) {
                                    AppNotifier.error(
                                      context,
                                      'No disponible. Reinicia la app completa para registrar plugins.',
                                    );
                                    return;
                                  }
                                  final next = _reminderSettings.copyWith(
                                    enabled: value,
                                  );
                                  await _updateReminderSettings(
                                    next,
                                    requestPermission: value,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _reminderPluginAvailable
                                    ? _openReminderSetup
                                    : null,
                                icon: const Icon(Icons.tune_rounded),
                                label: const Text(
                                  'Configurar horario e intervalo',
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

class _HydrationBackdrop extends StatelessWidget {
  final Animation<double> animation;

  const _HydrationBackdrop({required this.animation});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final driftA = math.sin(t * math.pi * 2) * 12;
        final driftB = math.cos(t * math.pi * 2) * 10;

        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HydrationWavePainter(progress: t, isDark: isDark),
              ),
            ),
            Positioned(
              top: -120 + driftA,
              right: -70 + driftB,
              child: _WaterBlob(
                size: 280,
                color: isDark
                    ? const Color(0x5528D4FF)
                    : const Color(0x3336D0FF),
              ),
            ),
            Positioned(
              top: 220 + driftB,
              left: -80 + driftA,
              child: _WaterBlob(
                size: 220,
                color: isDark
                    ? const Color(0x3324B7FF)
                    : const Color(0x2234B4FF),
              ),
            ),
            Positioned(
              bottom: -90 + driftA,
              right: -30 + driftB,
              child: _WaterBlob(
                size: 180,
                color: isDark
                    ? const Color(0x3326E2FF)
                    : const Color(0x1F27B8FF),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HydrationWavePainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _HydrationWavePainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = (isDark ? const Color(0x2E74D8FF) : const Color(0x2672BDE9));

    final yStart = size.height * 0.62;
    for (var i = 0; i < 4; i++) {
      final path = Path();
      final baseY = yStart + i * 24;
      path.moveTo(-20, baseY);
      for (double x = -20; x <= size.width + 20; x += 14) {
        final y = baseY + math.sin((x / 85) + progress * 6 + i) * (7 + i * 1.8);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HydrationWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}

class _WaterBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _WaterBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0.35, 1],
        ),
      ),
    );
  }
}

class _HydrationCelebrationOverlay extends StatelessWidget {
  final Animation<double> animation;

  const _HydrationCelebrationOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _HydrationCelebrationPainter(progress: animation.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _HydrationCelebrationPainter extends CustomPainter {
  final double progress;

  _HydrationCelebrationPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOut.transform(progress.clamp(0.0, 1.0));
    final fade = (1 - t).clamp(0.0, 1.0);
    final origin = Offset(size.width / 2, 90);
    final colors = <Color>[
      const Color(0xFF6EE7FF),
      const Color(0xFF8F62FF),
      const Color(0xFF1BD6FF),
      const Color(0xFF9EE8FF),
      const Color(0xFF7C5CFF),
    ];

    for (var i = 0; i < 42; i++) {
      final baseAngle = (i * 23.0) % 360;
      final angle = (baseAngle - 180) * math.pi / 180;
      final speed = 110 + (i % 8) * 16;
      final drift = (i.isEven ? 1 : -1) * (i % 5) * 2.0;

      final dx = math.cos(angle) * speed * t + drift;
      final dy = math.sin(angle) * speed * t + 320 * t * t;
      final position = origin + Offset(dx, dy);

      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: 0.95 * fade)
        ..style = PaintingStyle.fill;

      final radius = 3.0 + (i % 3) * 1.2;
      canvas.drawCircle(position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HydrationCelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _HydrationStatusBadge extends StatelessWidget {
  final String percent;

  const _HydrationStatusBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.34),
          width: 1.4,
        ),
      ),
      child: Center(
        child: Text(
          '$percent%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _HydrationTile extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final VoidCallback onTap;

  const _HydrationTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: NutrifotoColors.accentBlue.withValues(
                  alpha: isDark ? 0.24 : 0.18,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: NutrifotoColors.accentBlue, size: 20),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              amount,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? NutrifotoColors.textMuted : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
