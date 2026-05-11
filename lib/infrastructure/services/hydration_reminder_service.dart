import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class HydrationReminderSettings {
  final bool enabled;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final int intervalMinutes;

  const HydrationReminderSettings({
    required this.enabled,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.intervalMinutes,
  });

  const HydrationReminderSettings.defaults()
    : enabled = false,
      startHour = 8,
      startMinute = 0,
      endHour = 20,
      endMinute = 0,
      intervalMinutes = 120;

  HydrationReminderSettings copyWith({
    bool? enabled,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? intervalMinutes,
  }) {
    return HydrationReminderSettings(
      enabled: enabled ?? this.enabled,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    );
  }

  String get summary {
    return 'Cada ${intervalMinutes} min · ${_fmt(startHour, startMinute)} - ${_fmt(endHour, endMinute)}';
  }

  static String _fmt(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class HydrationReminderService {
  HydrationReminderService._();

  static final HydrationReminderService instance = HydrationReminderService._();

  static const _channelId = 'hydration_reminders';
  static const _channelName = 'Hydration Reminders';
  static const _channelDescription =
      'Recordatorios para beber agua durante el dia';

  static const _idBase = 47000;
  static const _maxReminderSlots = 60;

  static const _enabledKey = 'hydration_reminders_enabled';
  static const _startHourKey = 'hydration_reminders_start_hour';
  static const _startMinuteKey = 'hydration_reminders_start_minute';
  static const _endHourKey = 'hydration_reminders_end_hour';
  static const _endMinuteKey = 'hydration_reminders_end_minute';
  static const _intervalKey = 'hydration_reminders_interval';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _pluginAvailable = true;
  bool _storageAvailable = true;
  HydrationReminderSettings _cachedSettings =
      const HydrationReminderSettings.defaults();

  bool get isPluginAvailable => _pluginAvailable;
  bool get isStorageAvailable => _storageAvailable;

  Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      _pluginAvailable = false;
      _initialized = true;
      return;
    }

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();

      await _notifications.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _pluginAvailable = true;
    } on MissingPluginException {
      _pluginAvailable = false;
      _initialized = true;
      return;
    } on PlatformException {
      _pluginAvailable = false;
      _initialized = true;
      return;
    } catch (_) {
      _pluginAvailable = false;
      _initialized = true;
      return;
    }

    // Timezone support improves scheduling accuracy, but reminders can still
    // work using the current tz.local fallback if this plugin is unavailable.
    try {
      tz.initializeTimeZones();
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      try {
        tz.initializeTimeZones();
      } catch (_) {
        // Keep default tz.local.
      }
    }

    _initialized = true;
  }

  Future<bool> requestPermissionsIfNeeded() async {
    await initialize();
    if (!_pluginAvailable) {
      return false;
    }

    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();

      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);

      final macos = _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      await macos?.requestPermissions(alert: true, badge: true, sound: true);
      return true;
    } on MissingPluginException {
      _pluginAvailable = false;
      return false;
    } on PlatformException {
      _pluginAvailable = false;
      return false;
    } catch (_) {
      _pluginAvailable = false;
      return false;
    }
  }

  Future<HydrationReminderSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loaded = HydrationReminderSettings(
        enabled: prefs.getBool(_enabledKey) ?? false,
        startHour: prefs.getInt(_startHourKey) ?? 8,
        startMinute: prefs.getInt(_startMinuteKey) ?? 0,
        endHour: prefs.getInt(_endHourKey) ?? 20,
        endMinute: prefs.getInt(_endMinuteKey) ?? 0,
        intervalMinutes: prefs.getInt(_intervalKey) ?? 120,
      );
      _storageAvailable = true;
      _cachedSettings = loaded;
      return loaded;
    } on MissingPluginException {
      _storageAvailable = false;
      return _cachedSettings;
    } on PlatformException {
      _storageAvailable = false;
      return _cachedSettings;
    } catch (_) {
      _storageAvailable = false;
      return _cachedSettings;
    }
  }

  Future<bool> saveSettings(HydrationReminderSettings settings) async {
    _cachedSettings = settings;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, settings.enabled);
      await prefs.setInt(_startHourKey, settings.startHour);
      await prefs.setInt(_startMinuteKey, settings.startMinute);
      await prefs.setInt(_endHourKey, settings.endHour);
      await prefs.setInt(_endMinuteKey, settings.endMinute);
      await prefs.setInt(_intervalKey, settings.intervalMinutes);
      _storageAvailable = true;
    } on MissingPluginException {
      _storageAvailable = false;
    } on PlatformException {
      _storageAvailable = false;
    } catch (_) {
      _storageAvailable = false;
    }

    try {
      if (settings.enabled) {
        await _scheduleNotifications(settings);
      } else {
        await _cancelHydrationNotifications();
      }
      return _pluginAvailable;
    } on MissingPluginException {
      _pluginAvailable = false;
      return false;
    } on PlatformException {
      _pluginAvailable = false;
      return false;
    } catch (_) {
      _pluginAvailable = false;
      return false;
    }
  }

  Future<void> _cancelHydrationNotifications() async {
    if (!_pluginAvailable) {
      return;
    }
    for (var i = 0; i < _maxReminderSlots; i++) {
      await _notifications.cancel(_idBase + i);
    }
  }

  Future<void> _scheduleNotifications(
    HydrationReminderSettings settings,
  ) async {
    await initialize();
    if (!_pluginAvailable) {
      return;
    }
    await _cancelHydrationNotifications();

    final now = DateTime.now();
    final todayStart = DateTime(
      now.year,
      now.month,
      now.day,
      settings.startHour,
      settings.startMinute,
    );
    var todayEnd = DateTime(
      now.year,
      now.month,
      now.day,
      settings.endHour,
      settings.endMinute,
    );

    if (!todayEnd.isAfter(todayStart)) {
      todayEnd = todayEnd.add(const Duration(days: 1));
    }

    final slots = <DateTime>[];
    var current = todayStart;
    while (current.isBefore(todayEnd) && slots.length < _maxReminderSlots) {
      if (current.isAfter(now)) {
        slots.add(current);
      }
      current = current.add(Duration(minutes: settings.intervalMinutes));
    }

    if (slots.isEmpty) {
      current = todayStart.add(const Duration(days: 1));
      todayEnd = todayEnd.add(const Duration(days: 1));
      while (current.isBefore(todayEnd) && slots.length < _maxReminderSlots) {
        slots.add(current);
        current = current.add(Duration(minutes: settings.intervalMinutes));
      }
    }

    final cappedSlots = slots.take(math.min(slots.length, _maxReminderSlots));

    for (var i = 0; i < cappedSlots.length; i++) {
      final when = tz.TZDateTime.from(cappedSlots.elementAt(i), tz.local);

      await _notifications.zonedSchedule(
        _idBase + i,
        'Hora de hidratarte',
        'Bebe un vaso de agua para mantener tu progreso.',
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }
}
