// lib/shared/models/agent_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'auth_model.dart'; // Import AgentProfile from auth_model

part 'agent_model.freezed.dart';
part 'agent_model.g.dart';

// Agent Status Enum (for detailed profile, different from auth status)
enum AgentStatus {
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

// Agent Stats
@freezed
abstract class AgentStats with _$AgentStats {
  const factory AgentStats({
    required String agentId,
    @Default(0.0) double todaySales,
    @Default(0.0) double weekSales,
    @Default(0.0) double monthSales,
    @Default(0.0) double totalSales,
    @Default(0) int successfulTransactions,
    @Default(0) int failedTransactions,
    @Default(0) int pendingTransactions,
    @Default(0.0) double todayCommission,
    @Default(0.0) double totalCommission,
    @Default(0.0) double successRate,
    @Default(0.0) double averageTransactionValue,
    DateTime? lastTransactionAt,
    @Default(0) int activeDays,
  }) = _AgentStats;

  factory AgentStats.fromJson(Map<String, dynamic> json) =>
      _$AgentStatsFromJson(json);
}

// Agent Activity
@freezed
abstract class AgentActivity with _$AgentActivity {
  const factory AgentActivity({
    required String id,
    required String agentId,
    required String activityType,
    required String description,
    required DateTime timestamp,
    String? ipAddress,
    String? deviceId,
    Map<String, dynamic>? metadata,
  }) = _AgentActivity;

  factory AgentActivity.fromJson(Map<String, dynamic> json) =>
      _$AgentActivityFromJson(json);
}

// Agent Settings
@freezed
abstract class AgentSettings with _$AgentSettings {
  const factory AgentSettings({
    required String agentId,
    @Default(true) bool biometricEnabled,
    @Default(true) bool notificationsEnabled,
    @Default(true) bool transactionSounds,
    @Default('en') String language,
    @Default('light') String theme,
    @Default(5000.0) double transactionLimit,
    @Default(100000.0) double dailyLimit,
    @Default(true) bool autoLogoutEnabled,
    @Default(15) int logoutTimeoutMinutes,
    @Default(false) bool debugMode,
    Map<String, dynamic>? customSettings,
  }) = _AgentSettings;

  factory AgentSettings.fromJson(Map<String, dynamic> json) =>
      _$AgentSettingsFromJson(json);
}

// Agent Document
@freezed
abstract class AgentDocument with _$AgentDocument {
  const factory AgentDocument({
    required String id,
    required String agentId,
    required String documentType,
    required String documentUrl,
    required String status,
    required DateTime uploadedAt,
    DateTime? verifiedAt,
    String? verifiedBy,
    String? rejectionReason,
    @Default('') String notes,
  }) = _AgentDocument;

  factory AgentDocument.fromJson(Map<String, dynamic> json) =>
      _$AgentDocumentFromJson(json);
}

// Agent Tier
@freezed
abstract class AgentTier with _$AgentTier {
  const factory AgentTier({
    required String tierId,
    required String name,
    @Default('BRONZE') String level,
    @Default(0.0) double minVolume,
    @Default(0.0) double maxVolume,
    @Default(0.0) double commissionRate,
    @Default([]) List<String> benefits,
    @Default(false) bool isActive,
  }) = _AgentTier;

  factory AgentTier.fromJson(Map<String, dynamic> json) =>
      _$AgentTierFromJson(json);
}

// ===== REMOVED DUPLICATE AgentProfile =====
// The AgentProfile is now imported from auth_model.dart
// ==========================================

// Agent Detailed Profile
@freezed
abstract class AgentDetailedProfile with _$AgentDetailedProfile {
  const factory AgentDetailedProfile({
    // Basic fields - match AgentProfile but with AgentStatus
    required String id,
    required String fullName,
    required String phoneNumber,
    required String email,
    @JsonKey(unknownEnumValue: AgentStatus.pending)
    required AgentStatus status,
    required double tokenBalance,
    required DateTime registeredAt,
    DateTime? lastLoginAt,
    String? nationalId,
    String? agentCode,
    String? businessName,
    String? location,
    double? totalCommission,
    int? totalTransactions,
    double? successRate,
    
    // Payment fields
    String? tillNumber,
    String? paybillNumber,
    String? paybillAccount,
    bool? tillNumberVerified,
    DateTime? tillNumberVerifiedAt,
    String? tillNumberStatus,
    String? defaultPaymentMethod,
    Map<String, dynamic>? paymentSettings,
    
    // Additional detailed fields
    AgentStats? stats,
    AgentSettings? settings,
    List<AgentDocument>? documents,
    AgentTier? tier,
    Map<String, dynamic>? metadata,
  }) = _AgentDetailedProfile;

  factory AgentDetailedProfile.fromJson(Map<String, dynamic> json) =>
      _$AgentDetailedProfileFromJson(json);
}

// Agent List Response
@freezed
abstract class AgentListResponse with _$AgentListResponse {
  const factory AgentListResponse({
    required List<AgentDetailedProfile> agents,
    required int totalCount,
    required int page,
    required int pageSize,
    required bool hasNextPage,
  }) = _AgentListResponse;

  factory AgentListResponse.fromJson(Map<String, dynamic> json) =>
      _$AgentListResponseFromJson(json);
}