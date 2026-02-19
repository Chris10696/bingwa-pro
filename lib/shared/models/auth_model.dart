import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_model.freezed.dart';
part 'auth_model.g.dart';

// Define AgentStatus here to avoid circular imports
// Or keep it in agent_model.dart and use string for now
enum AgentAuthStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('ACTIVE')
  active,
  @JsonValue('SUSPENDED')
  suspended,
  @JsonValue('TERMINATED')
  terminated,
  @JsonValue('PENDING_VERIFICATION')
  pendingVerification,
}

// Login Request
@freezed
abstract class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    required String phoneNumber,
    required String pin,
    required String deviceId,
    @Default('android') String platform,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
}

// Login Response
@freezed
abstract class LoginResponse with _$LoginResponse {
  const factory LoginResponse({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    required AgentProfile agent,
    @Default(false) bool requiresBiometricSetup,
  }) = _LoginResponse;

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);
}

// Agent Profile (Keep it here but simplified)
@freezed
abstract class AgentProfile with _$AgentProfile {
  const factory AgentProfile({
    required String id,
    required String fullName,
    required String phoneNumber,
    required String email,
    @JsonKey(unknownEnumValue: AgentAuthStatus.pending)
    required AgentAuthStatus status,
    required double tokenBalance,
    required DateTime registeredAt,
    DateTime? lastLoginAt,
    @Default('') String nationalId,
    @Default('') String agentCode,
    @Default('') String businessName,
    @Default('') String location,
    @Default(0.0) double totalCommission,
    @Default(0) int totalTransactions,
    @Default(0.0) double successRate,
    Map<String, dynamic>? metadata,
  }) = _AgentProfile;

  factory AgentProfile.fromJson(Map<String, dynamic> json) =>
      _$AgentProfileFromJson(json);
}

// Agent Update Request (Keep only one - in auth_model)
@freezed
abstract class AgentUpdateRequest with _$AgentUpdateRequest {
  const factory AgentUpdateRequest({
    String? fullName,
    String? email,
    String? businessName,
    String? location,
    String? nationalId,
    String? agentCode,
  }) = _AgentUpdateRequest;

  factory AgentUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$AgentUpdateRequestFromJson(json);
}

// Registration Request
@freezed
abstract class RegistrationRequest with _$RegistrationRequest {
  const factory RegistrationRequest({
    required String fullName,
    required String phoneNumber,
    required String nationalId,
    required String email,
    required String pin,
    required String confirmPin,
    String? agentCode,
    String? businessName,
    String? location,
    required String deviceId,
    @Default('android') String platform,
  }) = _RegistrationRequest;

  factory RegistrationRequest.fromJson(Map<String, dynamic> json) =>
      _$RegistrationRequestFromJson(json);
}

// Registration Response
@freezed
abstract class RegistrationResponse with _$RegistrationResponse {
  const factory RegistrationResponse({
    required String message,
    required String agentId,
    String? verificationToken,  // Make it nullable instead of default
    DateTime? verificationExpiry,
    @Default(false) bool requiresManualApproval,
  }) = _RegistrationResponse;

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) =>
      _$RegistrationResponseFromJson(json);
}

// Verification Request
@freezed
abstract class VerificationRequest with _$VerificationRequest {
  const factory VerificationRequest({
    required String agentId,
    required String verificationToken,
    required String otp,
  }) = _VerificationRequest;

  factory VerificationRequest.fromJson(Map<String, dynamic> json) =>
      _$VerificationRequestFromJson(json);
}

// PIN Reset Request
@freezed
abstract class PinResetRequest with _$PinResetRequest {
  const factory PinResetRequest({
    required String phoneNumber,
    required String nationalId,
    required String newPin,
    required String confirmPin,
    required String otp,
  }) = _PinResetRequest;

  factory PinResetRequest.fromJson(Map<String, dynamic> json) =>
      _$PinResetRequestFromJson(json);
}

// Biometric Setup Request
@freezed
abstract class BiometricSetupRequest with _$BiometricSetupRequest {
  const factory BiometricSetupRequest({
    required String agentId,
    required String publicKey,
    required String deviceId,
  }) = _BiometricSetupRequest;

  factory BiometricSetupRequest.fromJson(Map<String, dynamic> json) =>
      _$BiometricSetupRequestFromJson(json);
}

// Session Info
@freezed
abstract class SessionInfo with _$SessionInfo {
  const factory SessionInfo({
    required String agentId,
    required DateTime loginTime,
    required DateTime expiryTime,
    required String deviceId,
    required String ipAddress,
    @Default('') String location,
    @Default(false) bool isActive,
  }) = _SessionInfo;

  factory SessionInfo.fromJson(Map<String, dynamic> json) =>
      _$SessionInfoFromJson(json);
}