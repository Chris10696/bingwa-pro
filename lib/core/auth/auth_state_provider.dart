// lib/core/auth/auth_state_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/secure_storage_manager.dart';
import '../utils/logger.dart';

/// Resolved synchronously in main() before the app is built. Overridden via
/// ProviderScope so the router can read it the first time redirect fires.
final initialAuthStateProvider = Provider<bool>((ref) {
  throw UnimplementedError(
    'initialAuthStateProvider must be overridden in main.dart before runApp',
  );
});

/// Single source of truth for "is the user authenticated right now?".
/// Extends ChangeNotifier so GoRouter can listen to it via refreshListenable.
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(bool initial) : _isAuthenticated = initial;

  bool _isAuthenticated;
  bool get isAuthenticated => _isAuthenticated;

  /// Call after successful login.
  void markAuthenticated() {
    if (!_isAuthenticated) {
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  /// Call after logout, token expiry, or refresh failure.
  void markUnauthenticated() {
    if (_isAuthenticated) {
      _isAuthenticated = false;
      notifyListeners();
    }
  }

  /// Re-reads from disk. Useful on app resume or after a refresh-token cycle.
  Future<void> refreshFromStorage() async {
    try {
      final valid = await SecureStorageManager.isSessionValid();
      if (valid != _isAuthenticated) {
        _isAuthenticated = valid;
        notifyListeners();
      }
    } catch (e, st) {
      AppLogger.e('AuthStateNotifier.refreshFromStorage failed', e, st);
    }
  }
}

final authStateProvider = ChangeNotifierProvider<AuthStateNotifier>((ref) {
  final initial = ref.watch(initialAuthStateProvider);
  return AuthStateNotifier(initial);
});