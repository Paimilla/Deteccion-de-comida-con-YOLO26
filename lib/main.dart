import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'application/app_bootstrap.dart';
import 'application/app_routes.dart';
import 'application/app_services.dart';
import 'presentation/screens/plan_screen.dart';
import 'presentation/screens/statistics_screen.dart';
import 'presentation/screens/achievements_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/recipes_screen.dart';
import 'presentation/screens/scanner_camera_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/assistant_screen.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/signup_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/widgets/nutrifoto_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final services = await AppBootstrap.initialize();
    final hasUserProfile = await services.trackingUseCases.hasUserProfile();
    final isLoggedIn = services.authService.isLoggedIn;
    runApp(
      NutrifotoApp(
        services: services,
        hasUserProfile: hasUserProfile,
        isLoggedIn: isLoggedIn,
      ),
    );
  } catch (e, stack) {
    debugPrint('❌ CRITICAL BOOTSTRAP ERROR: $e');
    debugPrint('Stack: $stack');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al iniciar Nutrifoto',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NutrifotoApp extends StatefulWidget {
  final AppServices services;
  final bool hasUserProfile;
  final bool isLoggedIn;

  const NutrifotoApp({
    super.key,
    required this.services,
    required this.hasUserProfile,
    required this.isLoggedIn,
  });

  @override
  State<NutrifotoApp> createState() => _NutrifotoAppState();
}

class _NutrifotoAppState extends State<NutrifotoApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeData _enhanceTheme(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;

    return base.copyWith(
      visualDensity: VisualDensity.standard,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isDark
            ? const Color(0xFF1C2A49)
            : const Color(0xFF253764),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: (base.filledButtonTheme.style ?? FilledButton.styleFrom())
            .copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
              textStyle: const WidgetStatePropertyAll(
                TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return _enhanceTheme(
      ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: NutrifotoColors.primary,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: NutrifotoColors.bg,
        textTheme: GoogleFonts.manropeTextTheme(
          ThemeData.dark().textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
        appBarTheme: const AppBarTheme(
          backgroundColor: NutrifotoColors.bg,
          centerTitle: false,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        cardTheme: CardThemeData(
          color: NutrifotoColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: NutrifotoColors.surface,
          labelStyle: const TextStyle(color: NutrifotoColors.textMuted),
          hintStyle: const TextStyle(color: NutrifotoColors.textMuted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2A3B67)),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF32487A)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF14213D),
          height: 82,
          indicatorColor: NutrifotoColors.primary.withValues(alpha: 0.22),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          elevation: 0,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: NutrifotoColors.primary,
                size: 27,
              );
            }
            return const IconThemeData(color: Color(0xFF99A4BE), size: 25);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? NutrifotoColors.primary
                  : const Color(0xFF99A4BE),
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: NutrifotoColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    const lightBg = Color(0xFFF6F8FF);
    const lightSurface = Colors.white;

    return _enhanceTheme(
      ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: NutrifotoColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: lightBg,
        textTheme: GoogleFonts.manropeTextTheme(ThemeData.light().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: lightBg,
          centerTitle: false,
          foregroundColor: Color(0xFF1B2449),
          elevation: 0,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2449),
            letterSpacing: -0.2,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: lightSurface,
          height: 82,
          indicatorColor: NutrifotoColors.primary.withValues(alpha: 0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          elevation: 0,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: NutrifotoColors.primary,
                size: 27,
              );
            }
            return const IconThemeData(color: Color(0xFF7080A6), size: 25);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? NutrifotoColors.primary
                  : const Color(0xFF7080A6),
            );
          }),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        cardTheme: CardThemeData(
          color: lightSurface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nutrifoto',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            final focus = FocusScope.of(context);
            if (!focus.hasPrimaryFocus && focus.focusedChild != null) {
              focus.unfocus();
            }
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _themeMode,
      initialRoute: (widget.hasUserProfile && widget.isLoggedIn)
          ? AppRoutes.hoy
          : widget.hasUserProfile
          ? AppRoutes
                .hoy // Tiene perfil pero no auth → dejarlo entrar
          : AppRoutes.welcome,
      routes: {
        // Fitia Navigation Tabs
        AppRoutes.hoy: (_) => HomeScreen(services: widget.services),
        AppRoutes.plan: (_) => PlanScreen(services: widget.services),
        AppRoutes.progreso: (_) => StatisticsScreen(services: widget.services),
        AppRoutes.welcome: (_) => WelcomeScreen(services: widget.services),
        AppRoutes.signup: (_) => SignupScreen(services: widget.services),
        AppRoutes.onboarding: (_) => OnboardingScreen(services: widget.services),
        AppRoutes.scannerCamera: (_) => ScannerCameraScreen(services: widget.services),
        AppRoutes.recipes: (_) => RecipesScreen(services: widget.services),
        AppRoutes.achievements: (_) => AchievementsScreen(services: widget.services),
        AppRoutes.assistant: (_) => AssistantScreen(services: widget.services),
        AppRoutes.perfil: (_) => SettingsScreen(
          services: widget.services,
          isDarkMode: _themeMode == ThemeMode.dark,
          onThemeChanged: (isDark) {
            setState(() {
              _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
            });
          },
        ),
      },
    );
  }
}
