import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════════
// RegistrationTracker — Registro remoto de usuarios para analítica
// ═══════════════════════════════════════════════════════════════════════════════
// Envía un POST con los datos del registro a un webhook configurable.
// 
// Opciones de webhook gratuitas:
//  • Google Apps Script → Google Sheets (recomendado, instrucciones en README)
//  • Discord Webhook
//  • Slack Incoming Webhook
//  • Cualquier endpoint HTTP que acepte JSON
//
// El webhook URL se configura vía --dart-define=REGISTRATION_WEBHOOK_URL=...
// Si no se configura, los registros solo se guardan en log local.
// ═══════════════════════════════════════════════════════════════════════════════

class RegistrationTracker {
  final String _webhookUrl;
  final http.Client _client;

  RegistrationTracker({
    required String webhookUrl,
    http.Client? client,
  })  : _webhookUrl = webhookUrl,
        _client = client ?? http.Client();

  /// Registra un evento de nuevo usuario.
  /// No bloquea la UI — se ejecuta en background y falla silenciosamente.
  Future<void> trackRegistration({
    required String name,
    required String email,
    required String provider, // 'google', 'email', 'guest'
    String? source, // "¿Cómo me conociste?" para invitados
    String? photoUrl,
  }) async {
    final payload = {
      'timestamp': DateTime.now().toIso8601String(),
      'name': name,
      'email': email,
      'provider': provider,
      'source': source ?? 'directo',
      'photoUrl': photoUrl ?? '',
      'platform': defaultTargetPlatform.name,
      'appVersion': '1.0.0',
    };

    debugPrint('📊 RegistrationTracker: Nuevo registro — $name ($provider)');

    if (_webhookUrl.isEmpty) {
      debugPrint('⚠️ RegistrationTracker: No hay webhook configurado. Solo log local.');
      return;
    }

    try {
      // Google Apps Script responde con 302 redirect.
      // Usamos HttpClient para seguir redirects automáticamente.
      final uri = Uri.parse(_webhookUrl);
      final jsonBody = jsonEncode(payload);

      // Primer intento: POST directo
      final response = await _client
          .post(uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonBody)
          .timeout(const Duration(seconds: 8));

      // Google Apps Script devuelve 302 → seguir el redirect con GET
      if (response.statusCode == 302 || response.statusCode == 301) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          final redirectResponse = await _client
              .get(Uri.parse(redirectUrl))
              .timeout(const Duration(seconds: 5));
          debugPrint('✅ RegistrationTracker: Enviado (redirect → ${redirectResponse.statusCode})');
        } else {
          // El 302 de GAS igual escribe en el Sheet aunque no sigamos el redirect
          debugPrint('✅ RegistrationTracker: Enviado (302 — datos registrados)');
        }
      } else if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ RegistrationTracker: Enviado exitosamente');
      } else {
        debugPrint('⚠️ RegistrationTracker: HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Fallar silenciosamente — no bloquear el flujo del usuario
      debugPrint('⚠️ RegistrationTracker: Error enviando (no crítico): $e');
    }
  }

  /// Registra un evento de invitado (reclutador).
  Future<void> trackGuestVisit({
    required String name,
    required String source,
  }) async {
    return trackRegistration(
      name: name,
      email: 'guest@nutrifoto.app',
      provider: 'guest',
      source: source,
    );
  }
}
