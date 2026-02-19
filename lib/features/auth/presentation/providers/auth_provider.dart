import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:formz/formz.dart' show FormzInput, FormzSubmissionStatus, FormzSubmissionStatusX;
import '/../../shared/models/auth_model.dart';
import '/../../shared/repositories/auth_repository.dart';
import '/../../core/utils/validators.dart';
import '/../../core/security/secure_storage_manager.dart';
import '/../../core/security/device_fingerprint.dart';

// Form Models
class PhoneNumber extends FormzInput<String, String> {
  const PhoneNumber.pure() : super.pure('');
  const PhoneNumber.dirty([String value = '']) : super.dirty(value);
  
  @override
  String? validator(String? value) {
    return Validators.isValidSafaricomNumber(value);
  }
}

class Pin extends FormzInput<String, String> {
  const Pin.pure() : super.pure('');
  const Pin.dirty([String value = '']) : super.dirty(value);
  
  @override
  String? validator(String? value) {
    return Validators.isValidPin(value);
  }
}

class FullName extends FormzInput<String, String> {
  const FullName.pure() : super.pure('');
  const FullName.dirty([String value = '']) : super.dirty(value);
  
  @override
  String? validator(String? value) {
    return Validators.isValidFullName(value);
  }
}

class Email extends FormzInput<String, String> {
  const Email.pure() : super.pure('');
  const Email.dirty([String value = '']) : super.dirty(value);
  
  @override
  String? validator(String? value) {
    return Validators.isValidEmail(value);
  }
}

class NationalId extends FormzInput<String, String> {
  const NationalId.pure() : super.pure('');
  const NationalId.dirty([String value = '']) : super.dirty(value);
  
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
  
  AuthNotifier(this._authRepository) : super(AuthState());
  
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
    
    state = state.copyWith(
      status: FormzSubmissionStatus.success,
      agent: response.agent,
      isAuthenticated: true,
      isLoading: false,
      requiresBiometricSetup: response.requiresBiometricSetup,
      errorMessage: null,
    );
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
      await _authRepository.logout();
      
      state = AuthState();
    } catch (e) {
      // Even if API call fails, reset local state
      state = AuthState();
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
      
      state = state.copyWith(
        status: FormzSubmissionStatus.success,
        agent: response.agent,
        isAuthenticated: true,
        isLoading: false,
        requiresBiometricSetup: response.requiresBiometricSetup,
      );
    } catch (e) {
      state = state.copyWith(
        status: FormzSubmissionStatus.failure,
        errorMessage: 'Session refresh failed',
        isLoading: false,
        isAuthenticated: false,
      );
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
  return AuthNotifier(authRepository);
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