// lib/shared/models/subscription_plan_model.dart
// W1 new model. Matches backend src/subscriptions/entities/subscription-plan.entity.ts.

import 'subscription_package_model.dart' show SubscriptionType;

class SubscriptionPlan {
  final String id;
  final String agentId;
  // Nullable for coupon-redeemed grants.
  final String? subscriptionPackageId;
  final SubscriptionType type;
  // For LIMITED plans: tokens left to consume.
  final int? tokensRemaining;
  // For UNLIMITED plans: timestamp at which plan becomes inactive.
  final DateTime? expiresAt;
  final DateTime purchasedAt;
  final bool isActive;

  const SubscriptionPlan({
    required this.id,
    required this.agentId,
    this.subscriptionPackageId,
    required this.type,
    this.tokensRemaining,
    this.expiresAt,
    required this.purchasedAt,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      agentId: json['agentId'] as String,
      subscriptionPackageId: json['subscriptionPackageId'] as String?,
      type: SubscriptionType.fromString(json['type'] as String),
      tokensRemaining: (json['tokensRemaining'] as num?)?.toInt(),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      purchasedAt: DateTime.parse(json['purchasedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'agentId': agentId,
        'subscriptionPackageId': subscriptionPackageId,
        'type': type.toBackendValue(),
        'tokensRemaining': tokensRemaining,
        'expiresAt': expiresAt?.toIso8601String(),
        'purchasedAt': purchasedAt.toIso8601String(),
        'isActive': isActive,
      };

  /// Returns true if this plan can currently satisfy a USSD request.
  /// Mirrors the backend's hasUsableTokens semantics for a single plan row.
  bool get isUsable {
    if (!isActive) return false;
    switch (type) {
      case SubscriptionType.limited:
        return (tokensRemaining ?? 0) > 0;
      case SubscriptionType.unlimited:
        return expiresAt != null && expiresAt!.isAfter(DateTime.now());
    }
  }
}