import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// AuthService — Servicio de autenticación con Google Sign-In
// ═══════════════════════════════════════════════════════════════════════════════
// Maneja:
//  • Inicio de sesión con Google (google_sign_in)
//  • Persistencia de sesión local (SharedPreferences)
//  • Auto-creación de cuenta si el usuario no existe
//  • Cierre de sesión
//
// NO requiere Firebase Auth. Usa Google Sign-In standalone + almacenamiento
// local para mantener la sesión. Si se integra Firebase más adelante,
// este servicio es fácilmente extensible.
// ═══════════════════════════════════════════════════════════════════════════════

class AuthService {
  static const _keyUser = 'nutrifoto_auth_user';
  static const _keyLoggedIn = 'nutrifoto_logged_in';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  SharedPreferences? _prefs;

  /// Usuario actual autenticado (null si no hay sesión activa).
  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;

  /// ¿Hay una sesión activa?
  bool get isLoggedIn => _currentUser != null;

  // ═══════════════════════════════════════════════════════════════════════════
  // Inicialización
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inicializa el servicio y restaura la sesión persistida (si existe).
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _restoreSession();
  }

  /// Restaura la sesión del usuario desde SharedPreferences.
  Future<void> _restoreSession() async {
    final isLoggedIn = _prefs?.getBool(_keyLoggedIn) ?? false;
    if (!isLoggedIn) return;

    final userJson = _prefs?.getString(_keyUser);
    if (userJson == null || userJson.isEmpty) return;

    try {
      final data = jsonDecode(userJson) as Map<String, dynamic>;
      _currentUser = AuthUser.fromJson(data);
      debugPrint('✅ AuthService: Sesión restaurada para ${_currentUser?.displayName}');
    } catch (e) {
      debugPrint('⚠️ AuthService: Error restaurando sesión: $e');
      await _clearPersistedSession();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Google Sign-In
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inicia sesión con Google.
  /// Si el usuario no tiene cuenta, se crea automáticamente.
  /// Retorna el AuthUser o null si el usuario canceló.
  Future<AuthUser?> signInWithGoogle() async {
    try {
      debugPrint('🔐 AuthService: Iniciando Google Sign-In...');

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ AuthService: Usuario canceló Google Sign-In');
        return null; // El usuario canceló
      }

      // Obtener token de autenticación (para futuro uso con Firebase)
      final googleAuth = await googleUser.authentication;

      final user = AuthUser(
        id: googleUser.id,
        email: googleUser.email,
        displayName: googleUser.displayName ?? googleUser.email.split('@').first,
        photoUrl: googleUser.photoUrl,
        provider: AuthProvider.google,
        idToken: googleAuth.idToken,
        createdAt: DateTime.now(),
      );

      _currentUser = user;
      await _persistSession(user);

      debugPrint('✅ AuthService: Sesión iniciada — ${user.displayName} (${user.email})');
      return user;
    } catch (e) {
      debugPrint('❌ AuthService: Error en Google Sign-In: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Registro con email (local, sin backend)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea una cuenta local con email y contraseña.
  /// En una versión con backend, esto haría un POST al servidor.
  Future<AuthUser?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('📧 AuthService: Creando cuenta con email...');

      // Simular creación de cuenta (en producción, llamaría a Firebase/backend)
      final user = AuthUser(
        id: 'email_${email.hashCode.abs()}',
        email: email,
        displayName: name,
        provider: AuthProvider.email,
        createdAt: DateTime.now(),
      );

      _currentUser = user;
      await _persistSession(user);

      debugPrint('✅ AuthService: Cuenta creada — ${user.displayName}');
      return user;
    } catch (e) {
      debugPrint('❌ AuthService: Error creando cuenta: $e');
      return null;
    }
  }
  // ═══════════════════════════════════════════════════════════════════════════
  // Modo Invitado (para reclutadores y visitantes)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea una sesión de invitado. Solo requiere nombre y fuente.
  /// Ideal para reclutadores que quieren probar la app sin compromiso.
  Future<AuthUser> signInAsGuest({
    required String name,
    required String source,
  }) async {
    debugPrint('👤 AuthService: Creando sesión de invitado...');

    final user = AuthUser(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      email: 'guest@nutrifoto.app',
      displayName: name,
      provider: AuthProvider.guest,
      createdAt: DateTime.now(),
    );

    _currentUser = user;
    await _persistSession(user);

    debugPrint('✅ AuthService: Invitado creado — $name (fuente: $source)');
    return user;
  }

  /// ¿Es el usuario actual un invitado?
  bool get isGuest => _currentUser?.provider == AuthProvider.guest;

  // ═══════════════════════════════════════════════════════════════════════════
  // Cierre de sesión
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cierra la sesión activa y limpia datos persistidos.
  Future<void> signOut() async {
    try {
      // Siempre cerrar sesión de Google para limpiar el estado del picker
      await _googleSignIn.signOut();
      // disconnect() fuerza que el picker de cuentas aparezca la próxima vez
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint('⚠️ AuthService: Error cerrando sesión Google: $e');
    }

    _currentUser = null;
    await _clearPersistedSession();
    debugPrint('🔓 AuthService: Sesión cerrada');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Persistencia local
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _persistSession(AuthUser user) async {
    await _prefs?.setBool(_keyLoggedIn, true);
    await _prefs?.setString(_keyUser, jsonEncode(user.toJson()));
  }

  Future<void> _clearPersistedSession() async {
    await _prefs?.remove(_keyLoggedIn);
    await _prefs?.remove(_keyUser);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Modelos de autenticación
// ═══════════════════════════════════════════════════════════════════════════════

enum AuthProvider { google, email, guest }

class AuthUser {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final AuthProvider provider;
  final String? idToken;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.provider,
    this.idToken,
    required this.createdAt,
  });

  /// Iniciales para avatar cuando no hay foto
  String get initials {
    final parts = displayName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'provider': provider.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    displayName: json['displayName']?.toString() ?? '',
    photoUrl: json['photoUrl']?.toString(),
    provider: json['provider'] == 'google'
        ? AuthProvider.google
        : json['provider'] == 'guest'
            ? AuthProvider.guest
            : AuthProvider.email,
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );
}
