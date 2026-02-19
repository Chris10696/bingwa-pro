import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../security/secure_storage_manager.dart';
import '../utils/logger.dart';
import '../../app_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

class SessionManager {
  final Ref ref;
  Timer? _inactivityTimer;
  Timer? _warningTimer;
  DateTime? _lastActivityTime;
  bool _isTransactionActive = false;
  
  SessionManager(this.ref);
  
  // Start session timer
  void startSession() {
    _resetInactivityTimer();
  }
  
  // Record user activity
  void recordActivity() {
    if (!_isTransactionActive) {
      _lastActivityTime = DateTime.now();
      _resetInactivityTimer();
    }
  }
  
  // Pause timer during active transaction
  void pauseForTransaction() {
    _isTransactionActive = true;
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
  }
  
  // Resume timer after transaction completes
  void resumeAfterTransaction() {
    _isTransactionActive = false;
    _resetInactivityTimer();
  }
  
  // Reset the inactivity timer
  void _resetInactivityTimer() {
    // Cancel existing timers
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    
    // Calculate warning time (14 minutes)
    const warningTime = Duration(minutes: AppConstants.sessionTimeoutMinutes - 1);
    
    // Set warning timer
    _warningTimer = Timer(warningTime, _showSessionWarning);
    
    // Set logout timer
    _inactivityTimer = Timer(
      const Duration(minutes: AppConstants.sessionTimeoutMinutes),
      _logoutDueToInactivity,
    );
  }
  
  // Show session warning
  void _showSessionWarning() {
    // Show warning using a dialog or snackbar
    _logSessionEvent(
      event: 'Session warning shown',
      details: 'Session will expire in 1 minute',
    );
  }
  
  // Logout due to inactivity
  Future<void> _logoutDueToInactivity() async {
    _logSessionEvent(
      event: 'Auto-logout due to inactivity',
    );
    
    // Clear session data
    await SecureStorageManager.clearAll();
    
    // Trigger logout via Riverpod
    ref.read(authNotifierProvider.notifier).logout();
    
    // Navigate to login screen via router
    ref.read(appRouterProvider).go('/login');
  }
  
  // Force logout (manual)
  Future<void> forceLogout() async {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    
    await SecureStorageManager.clearAll();
    
    _logSessionEvent(
      event: 'Manual logout',
    );
    
    // Navigate to login screen
    ref.read(appRouterProvider).go('/login');
  }
  
  // Check if session is about to expire
  bool isSessionAboutToExpire() {
    if (_lastActivityTime == null) return false;
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastActivityTime!);
    final minutesElapsed = elapsed.inMinutes;
    
    return minutesElapsed >= (AppConstants.sessionTimeoutMinutes - 1);
  }
  
  // Get remaining session time
  Duration? getRemainingSessionTime() {
    if (_lastActivityTime == null) return null;
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastActivityTime!);
    final totalDuration = Duration(minutes: AppConstants.sessionTimeoutMinutes);
    
    if (elapsed > totalDuration) {
      return Duration.zero;
    }
    
    return totalDuration - elapsed;
  }
  
  // Check if user is authenticated (has valid auth token)
  Future<bool> isUserAuthenticated() async {
    return await SecureStorageManager.isLoggedIn();
  }
  
  // Check if session is valid
  Future<bool> isSessionValid() async {
    return await SecureStorageManager.isSessionValid();
  }
  
  // Alternative name for compatibility (both work)
  Future<bool> hasValidSession() async {
    return await isSessionValid();
  }
  
  // Check authentication status with PIN
  Future<bool> checkAuthStatus() async {
    // First check if we have a valid token
    final hasToken = await SecureStorageManager.getAuthToken() != null;
    
    // Check if session is still valid
    final sessionValid = await isSessionValid();
    
    return hasToken && sessionValid;
  }
  
  // Restore session on app start
  Future<void> restoreSession() async {
    try {
      final isValid = await isSessionValid();
      
      if (isValid) {
        final authNotifier = ref.read(authNotifierProvider.notifier);
        await authNotifier.checkAuthentication();
      }
    } catch (e) {
      _logSessionEvent(event: 'Session restore failed', details: e.toString());
    }
  }
  
  // Helper method to log session events with agent ID
  Future<void> _logSessionEvent({required String event, String? details}) async {
    final agentId = await SecureStorageManager.getAgentId();
    
    AppLogger.logSessionEvent(
      event: event,
      agentId: agentId,
      details: details,
    );
  }
  
  // Dispose timers
  void dispose() {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
  }
}

// Riverpod provider for session management
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final manager = SessionManager(ref);
  // Auto-dispose when provider is disposed
  ref.onDispose(() => manager.dispose());
  return manager;
});