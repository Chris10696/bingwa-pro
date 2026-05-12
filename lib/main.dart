// lib/main.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_router.dart';
import 'core/auth/auth_state_provider.dart';
import 'core/security/secure_storage_manager.dart';
import 'core/utils/logger.dart';

Future<void> main() async {
  // Catch ALL uncaught errors — including those thrown from plugin callbacks,
  // microtasks, and unhandled futures.
  await runZonedGuarded(() async {
    // 1. MUST be first. Plugin calls (dotenv, secure_storage) require it.
    WidgetsFlutterBinding.ensureInitialized();

    // 2. Hook framework errors so they're logged instead of crashing the UI.
    FlutterError.onError = (details) {
      AppLogger.e('FlutterError', details.exception, details.stack);
      FlutterError.presentError(details);
    };

    // 3. Hook errors thrown from platform code (Kotlin/Java).
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.e('PlatformDispatcher error', error, stack);
      return true; // signal: handled
    };

    // 4. Load .env. Don't crash if it's missing — fall back to defaults.
    try {
      await dotenv.load(fileName: '.env');
    } catch (e, st) {
      AppLogger.w('dotenv.load failed (continuing with defaults)', e, st);
    }

    // 5. Initialize secure storage. Don't crash on transient errors.
    try {
      await SecureStorageManager.initialize();
    } catch (e, st) {
      AppLogger.e('SecureStorageManager.initialize failed', e, st);
    }

    // 6. Pre-resolve auth state BEFORE building the router. This is the
    //    key fix for the session-persistence bug: previously this happened
    //    async in initState and raced against router redirect.
    final initialAuth = await _resolveInitialAuthState();
    AppLogger.i('Initial auth state resolved: $initialAuth');

    runApp(
      ProviderScope(
        overrides: [
          initialAuthStateProvider.overrideWithValue(initialAuth),
        ],
        child: const BingwaProApp(),
      ),
    );
  }, (error, stack) {
    AppLogger.e('Uncaught zone error', error, stack);
  });
}

Future<bool> _resolveInitialAuthState() async {
  try {
    return await SecureStorageManager.isSessionValid();
  } catch (e, st) {
    AppLogger.e('Auth state resolution failed', e, st);
    return false;
  }
}

class BingwaProApp extends ConsumerWidget {
  const BingwaProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Bingwa Pro',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }

  // --- Theme builders extracted for readability — content unchanged from
  //     your previous main.dart ---
  ThemeData _buildLightTheme() => ThemeData(
        primarySwatch: Colors.green,
        primaryColor: const Color(0xFF00C853),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF00C853),
          secondary: Color(0xFF64DD17),
          background: Colors.white,
          surface: Colors.white,
          error: Color(0xFFD32F2F),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.black,
          onSurface: Colors.black,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF00C853),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00C853), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: Colors.grey),
          hintStyle: const TextStyle(color: Colors.grey),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00C853),
            side: const BorderSide(color: Color(0xFF00C853)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF00C853),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          margin: EdgeInsets.symmetric(vertical: 8),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        useMaterial3: true,
      );

  ThemeData _buildDarkTheme() => ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00C853),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00C853),
          secondary: Color(0xFF64DD17),
          background: Color(0xFF121212),
          surface: Color(0xFF1E1E1E),
          error: Color(0xFFCF6679),
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        dialogBackgroundColor: const Color(0xFF1E1E1E),
      );
}