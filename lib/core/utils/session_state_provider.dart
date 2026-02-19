import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/secure_storage_manager.dart';

/// Cached session state to avoid repeated secure storage reads
class SessionState {
  final bool isAuthenticated;
  final bool isSessionValid;
  final bool hasBiometric;
  final DateTime lastChecked;

  SessionState({
    required this.isAuthenticated,
    required this.isSessionValid,
    required this.hasBiometric,
    required this.lastChecked,
  });

  bool get isExpired {
    return DateTime.now().difference(lastChecked).inSeconds > 5;
  }

  SessionState copyWith({
    bool? isAuthenticated,
    bool? isSessionValid,
    bool? hasBiometric,
    DateTime? lastChecked,
  }) {
    return SessionState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isSessionValid: isSessionValid ?? this.isSessionValid,
      hasBiometric: hasBiometric ?? this.hasBiometric,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

class SessionStateNotifier extends StateNotifier<SessionState?> {
  SessionStateNotifier() : super(null);

  Future<SessionState> getOrRefreshSessionState() async {
    // If we have a recent cached state (less than 5 seconds old), return it
    if (state != null && !state!.isExpired) {
      return state!;
    }

    // Otherwise, fetch fresh data
    final isAuthenticated = await SecureStorageManager.isLoggedIn();
    final isSessionValid = await SecureStorageManager.isSessionValid();
    final hasBiometric = await SecureStorageManager.hasBiometricEnabled();

    final newState = SessionState(
      isAuthenticated: isAuthenticated,
      isSessionValid: isSessionValid,
      hasBiometric: hasBiometric,
      lastChecked: DateTime.now(),
    );

    state = newState;
    return newState;
  }

  void invalidate() {
    state = null;
  }

  void updateAuthStatus({required bool isAuthenticated}) {
    if (state != null) {
      state = state!.copyWith(
        isAuthenticated: isAuthenticated,
        lastChecked: DateTime.now(),
      );
    }
  }
}

final sessionStateProvider = StateNotifierProvider<SessionStateNotifier, SessionState?>((ref) {
  return SessionStateNotifier();
});