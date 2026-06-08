// lib/features/auth/presentation/providers/auth_provider.dart
import 'package:bingwa_pro/core/utils/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formz/formz.dart' show FormzInput, FormzSubmissionStatus, FormzSubmissionStatusX;
import '../../../../shared/models/auth_model.dart';
import '../../../../shared/repositories/auth_repository.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/security/secure_storage_manager.dart';
import '../../../../core/security/device_fingerprint.dart';
import '../../../../core/auth/auth_state_provider.dart';
// W3.E / D-W3-19 (Option B): native session bridge for the background worker.
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/session_bridge_service.dart';
// Form Models
class PhoneNumber extends FormzInput<String, String> {
  const PhoneNumber.pure() : super.pure('');
  const PhoneNumber.dirty([super.value = '']) : super.dirty(); // FIX: super parameter
  
  @override
  String? validator(String? value) {
    return Validators.isValidSafaricomNumber(value);
  }
}
class Pin extends FormzInput<String, String> {
  const Pin.pure() : super.pure('');
  const Pin.dirty([super.value = '']) : super.dirty(); // FIX: super parameter
  
  @override
  String? validator(String? value) {
    return Validators.isValidPin(value);
  }
}
class FullName extends FormzInput<String, String> {
  const FullName.pure() : super.pure('');
  const FullName.dirty([super.value = '']) : super.dirty(); // FIX: super parameter
  
  @override
  String? validator(String? value) {
    return Validators.isValidFullName(value);
  }
}
class Email extends FormzInput<String, String> {
  const Email.pure() : super.pure('');
  const Email.dirty([super.value = '']) : super.dirty(); // FIX: super parameter
  
  @override
  String? validator(String? value) {
    return Validators.isValidEmail(value);
  }
}
class NationalId extends FormzInput<String, String> {
  const NationalId.pure() : super.pure('');
  const NationalId.dirty([super.value = '']) : super.dirty(); // FIX: super parameter
  
  @override
  String? validator(String? value) {
    return Validators.isValidNationalId(value);
  }
}

class ConfirmPin extends FormzInput<String, String> {
  final String pin;
  
  const ConfirmPin.pure({this.pin = ''}) : super.pure('');
  const ConfirmPin.dirty({required this.pin, String value = ''}) : super.dirty(value);
  
  @override
  String? validator(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm PIN is required';
    }
    if (value != pin) {
      return 'PINs do not match';
    }
    return null;
  }
}
// Auth State
class AuthState {
  final PhoneNumber phoneNumber;
  final Pin pin;
  final FullName fullName;
  final Email email;
  final NationalId nationalId;
  final ConfirmPin confirmPin;
  final FormzSubmissionStatus status;
  final AgentProfile? agent;
  final String? errorMessage;
  final bool isAuthenticated;
  final bool isLoading;
  final bool isRegistering;
  final String? registrationToken;
  final bool requiresBiometricSetup;
  
  AuthState({
    this.phoneNumber = const PhoneNumber.pure(),
    this.pin = const Pin.pure(),
    this.fullName = const FullName.pure(),
    this.email = const Email.pure(),
    this.nationalId = const NationalId.pure(),
    this.confirmPin = const ConfirmPin.pure(),
    this.status = FormzSubmissionStatus.initial,
    this.agent,
    this.errorMessage,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.isRegistering = false,
    this.registrationToken,
    this.requiresBiometricSetup = false,
  });
  
  AuthState copyWith({
    PhoneNumber? phoneNumber,
    Pin? pin,
    FullName? fullName,
    Email? email,
    NationalId? nationalId,
    ConfirmPin? confirmPin,
    FormzSubmissionStatus? status,
    AgentProfile? agent,
    String? errorMessage,
    bool? isAuthenticated,
    bool? isLoading,
    bool? isRegistering,
    String? registrationToken,
    bool? requiresBiometricSetup,
  }) {
    return AuthState(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      pin: pin ?? this.pin,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      nationalId: nationalId ?? this.nationalId,
      confirmPin: confirmPin ?? this.confirmPin,
      status: status ?? this.status,
      agent: agent ?? this.agent,
      errorMessage: errorMessage ?? this.errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isRegistering: isRegistering ?? this.isRegistering,
      registrationToken: registrationToken ?? this.registrationToken,
      requiresBiometricSetup: requiresBiometricSetup ?? this.requiresBiometricSetup,
    );
  }
}

// Auth Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final Ref _ref; // ADD THIS for accessing other providers
  
  AuthNotifier(this._authRepository, this._ref) : super(AuthState());

  // W3.E / D-W3-19 (Option B): mirror the current session into the native store
  // so the background ScheduleTransactionWorker can authenticate. The worker runs
  // with no Flutter engine and cannot read flutter_secure_storage, so Dart mirrors
  // {accessToken, baseUrl, agentId} natively and the worker reads the current token
  // each time it fires. Reads from SecureStorageManager — the single source of truth
  // that auth_repository keeps current on BOTH login and refresh — so the value
  // pushed here is never stale. Non-fatal by design: a mirror failure must never
  // break the auth flow (SessionBridgeService also swallows its own errors).
  //
  // KNOWN COVERAGE GAP (flagged): a silent token refresh inside the Dio
  // 401-interceptor (repository level) does NOT pass through this notifier, so the
  // native mirror can lag until the next notifier-level auth event. Robust fix is to
  // mirror beside saveAuthToken inside auth_repository.refreshToken(); W3.J's 24/7
  // heartbeat (which drives periodic notifier-level refreshes) also closes it. Until
  // then the worker degrades gracefully: stale token -> 401 -> pre-dial retry ->
  // fires once the token is refreshed and re-mirrored.
  Future<void> _mirrorSessionToNative() async {
    try {
      final token = await SecureStorageManager.getAuthToken();
      final agentId = await SecureStorageManager.getAgentId();
      if (token == null || token.isEmpty || agentId == null || agentId.isEmpty) {
        return;
      }
      await _ref.read(sessionBridgeServiceProvider).setSession(
            accessToken: token,
            baseUrl: ApiConstants.baseUrl,
            agentId: agentId,
          );
    } catch (e) {
      AppLogger.w('Session mirror to native failed (non-fatal)', e);
    }
  }

  // Login Methods
  void updatePhoneNumber(String value) {
    state = state.copyWith(
      phoneNumber: PhoneNumber.dirty(value),
      errorMessage: null,
    );
  }
  
  void updatePin(String value) {
    state = state.copyWith(
      pin: Pin.dirty(value),
      errorMessage: null,
    );
  }
  
  Future<void> login() async {
    if (state.status.isInProgress) return;
    
    if (!state.phoneNumber.isValid || !state.pin.isValid) {
      state = state.copyWith(
        errorMessage: 'Please fix validation errors',
      );
      return;
    }
    
    state = state.copyWith(
      status: FormzSubmissionStatus.inProgress,
      isLoading: true,
      errorMessage: null,
    );
    
    try {
      // Generate or get device ID
      String deviceId = await SecureStorageManager.getDeviceId() ?? 
          await DeviceFingerprint.generateDeviceId();
      
      final request = LoginRequest(
        phoneNumber: state.phoneNumber.value,
        pin: state.pin.value,
        deviceId: deviceId,
        platform: 'android',
      );
      
      final response = await _authRepository.login(request);
      
      // Check agent status
      if (response.agent.status != AgentAuthStatus.active) {
        String statusMessage = 'Your account is ${response.agent.status.toString().split('.').last}. ';
        if (response.agent.status == AgentAuthStatus.pending) {
          statusMessage += 'Please wait for admin approval.';
        } else if (response.agent.status == AgentAuthStatus.suspended) {
          statusMessage += 'Please contact support.';
        }
        
        state = state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: statusMessage,
          isLoading: false,
          isAuthenticated: false,
        );
        return;
      }
      
      // Save device ID if not already saved
      if (await SecureStorageManager.getDeviceId() == null) {
        await SecureStorageManager.saveDeviceId(deviceId);
      }

      // Save session data
      await SecureStorageManager.saveAuthToken(response.accessToken);
      await SecureStorageManager.saveRefreshToken(response.refreshToken);
      await SecureStorageManager.saveSessionExpiry(response.expiresAt);
      await SecureStorageManager.saveAgentId(response.agent.id);

      // W3.E: mirror the freshly-saved session to native for the background worker.
      await _mirrorSessionToNative();

      state = state.copyWith(
        status: FormzSubmissionStatus.success,
        agent: response.agent,
        isAuthenticated: true,
        isLoading: false,
        requiresBiometricSetup: response.requiresBiometricSetup,
        errorMessage: null,
      );
      _ref.read(authStateProvider.notifier).markAuthenticated();
    } catch (e) {
      String errorMsg = e.toString();
      // Clean up error message
      if (errorMsg.startsWith('Exception:')) {
        errorMsg = errorMsg.substring(10);
      }
      
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: errorMsg.trim(),
        isLoading: false,
        isAuthenticated: false,
      );
    }
  }
  
  // Registration Methods
  void updateFullName(String value) {
    state = state.copyWith(
      fullName: FullName.dirty(value),
      errorMessage: null,
    );
  }
  
  void updateEmail(String value) {
    state = state.copyWith(
      email: Email.dirty(value),
      errorMessage: null,
    );
  }
  
  void updateNationalId(String value) {
    state = state.copyWith(
      nationalId: NationalId.dirty(value),
      errorMessage: null,
    );
  }
  
  void updateConfirmPin(String value) {
    state = state.copyWith(
      confirmPin: ConfirmPin.dirty(pin: state.pin.value, value: value),
      errorMessage: null,
    );
  }
  
  Future<void> register() async {
    if (state.status.isInProgress) return;
    
    // Validate all fields
    if (!state.phoneNumber.isValid ||
        !state.pin.isValid ||
        !state.fullName.isValid ||
        !state.email.isValid ||
        !state.nationalId.isValid ||
        !state.confirmPin.isValid) {
      state = state.copyWith(
        errorMessage: 'Please fix validation errors',
      );
      return;
    }
    
    state = state.copyWith(
      status: FormzSubmissionStatus.inProgress,
      isLoading: true,
      isRegistering: true,
      errorMessage: null,
    );

    try {
      // Generate device ID
      final deviceId = await DeviceFingerprint.generateDeviceId();
      
      final request = RegistrationRequest(
        fullName: state.fullName.value,
        phoneNumber: state.phoneNumber.value,
        nationalId: state.nationalId.value,
        email: state.email.value,
        pin: state.pin.value,
        confirmPin: state.confirmPin.value,
        deviceId: deviceId,
      );
      
      final response = await _authRepository.register(request);
      
      // Save device ID
      await SecureStorageManager.saveDeviceId(deviceId);
      
      state = state.copyWith(
        status: FormzSubmissionStatus.success,
        isLoading: false,
        isRegistering: false,
        registrationToken: response.verificationToken,
      );
    } catch (e) {
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: e.toString(),
        isLoading: false,
        isRegistering: false,
      );
    }
  }
  
  // Verification Methods
  Future<void> verifyPhone() async {
    if (state.status.isInProgress) return;
    
    if (!state.phoneNumber.isValid) {
      state = state.copyWith(
        errorMessage: 'Please enter a valid phone number',
      );
      return;
    }
    
    state = state.copyWith(
      status: FormzSubmissionStatus.inProgress,
      isLoading: true,
      errorMessage: null,
    );
    
    try {
      await _authRepository.verifyPhone(state.phoneNumber.value);
      
      state = state.copyWith(
        status: FormzSubmissionStatus.success,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: e.toString(),
        isLoading: false,
      );
    }
  }

  // PIN Reset Methods
  Future<void> resetPin({
    required String otp,
    required String newPin,
    required String confirmPin,
  }) async {
    if (state.status.isInProgress) return;
    
    if (!state.phoneNumber.isValid || !state.nationalId.isValid) {
      state = state.copyWith(
        errorMessage: 'Please enter valid phone and ID',
      );
      return;
    }
    
    if (newPin != confirmPin) {
      state = state.copyWith(
        errorMessage: 'PINs do not match',
      );
      return;
    }
    
    state = state.copyWith(
      status: FormzSubmissionStatus.inProgress,
      isLoading: true,
      errorMessage: null,
    );
    
    try {
      final request = PinResetRequest(
        phoneNumber: state.phoneNumber.value,
        nationalId: state.nationalId.value,
        newPin: newPin,
        confirmPin: confirmPin,
        otp: otp,
      );
      
      await _authRepository.resetPin(request);
      
      state = state.copyWith(
        status: FormzSubmissionStatus.success,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: e.toString(),
        isLoading: false,
      );
    }
  }
  
  // Session Management
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    
    try {
      // Call API logout endpoint
      await _authRepository.logout();
      
      // Clear all local storage
      await SecureStorageManager.clearAll();

      // W3.E: clear the native session mirror so a stale token can't be used by
      // the background worker after logout.
      await _ref.read(sessionBridgeServiceProvider).clear();

      // Reset state
      state = AuthState();
      _ref.read(authStateProvider.notifier).markUnauthenticated();
      
      AppLogger.logSessionEvent(event: 'Logout successful');
    } catch (e) {
      AppLogger.e('Logout error:', e);
      // Even if API fails, clear local state
      await SecureStorageManager.clearAll();
      // W3.E: clear native mirror on the failure path too.
      await _ref.read(sessionBridgeServiceProvider).clear();
      state = AuthState();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> checkAuthentication() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final isAuthenticated = await _authRepository.checkSessionValidity();
      
      if (isAuthenticated) {
        final agent = await _authRepository.getAgentProfile();
        
        state = state.copyWith(
          agent: agent,
          isAuthenticated: true,
          isLoading: false,
        );

        // W3.E: re-mirror on app-restart / session check (checkSessionValidity may
        // have refreshed the token), so the worker always has the current token.
        await _mirrorSessionToNative();
      } else {
        state = state.copyWith(
          isAuthenticated: false,
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isAuthenticated: false,
        isLoading: false,
        errorMessage: 'Session check failed',
      );
    }
  }
  
  Future<void> refreshSession() async {
    if (state.status.isInProgress) return;
    
    state = state.copyWith(
      status: FormzSubmissionStatus.inProgress,
      isLoading: true,
      errorMessage: null,
    );
    
    try {
      final response = await _authRepository.refreshToken();

      // W3.E: the repo persisted the new token to SecureStorageManager; mirror it
      // to native so the background worker keeps a valid token.
      await _mirrorSessionToNative();

      state = state.copyWith(
        status: FormzSubmissionStatus.success,
        agent: response.agent,
        isAuthenticated: true,
        isLoading: false,
        requiresBiometricSetup: response.requiresBiometricSetup,
      );
      _ref.read(authStateProvider.notifier).markAuthenticated();
    } catch (e) {
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Session refresh failed',
        isLoading: false,
        isAuthenticated: false,
      );
      _ref.read(authStateProvider.notifier).markUnauthenticated();
    }
  }

  // Biometric Setup
  Future<void> setupBiometric(String publicKey) async {
    if (state.agent == null) return;
    
    state = state.copyWith(isLoading: true);
    
    try {
      final deviceId = await SecureStorageManager.getDeviceId() ??
          await DeviceFingerprint.generateDeviceId();
      
      final request = BiometricSetupRequest(
        agentId: state.agent!.id,
        publicKey: publicKey,
        deviceId: deviceId,
      );
      
      await _authRepository.setupBiometric(request);
      
      state = state.copyWith(
        isLoading: false,
        requiresBiometricSetup: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Biometric setup failed',
      );
    }
  }
  
  // Clear Errors
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
  
  // Reset Registration
  void resetRegistration() {
    state = state.copyWith(
      isRegistering: false,
      registrationToken: null,
    );
  }
}
// Providers
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return AuthNotifier(authRepository, ref); // Pass ref to constructor
});
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isAuthenticated;
});
final currentAgentProvider = Provider<AgentProfile?>((ref) {
  return ref.watch(authNotifierProvider).agent;
});
final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authNotifierProvider).isLoading;
});