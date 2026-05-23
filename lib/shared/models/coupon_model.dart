// lib/shared/models/coupon_model.dart
// W2.B: result of POST /coupons/redeem. Mirrors Hybrid's response shape
// { name, durationHours }.
class CouponRedemptionResult {
  final String name;
  final double durationHours;

  const CouponRedemptionResult({
    required this.name,
    required this.durationHours,
  });

  factory CouponRedemptionResult.fromJson(Map<String, dynamic> json) {
    return CouponRedemptionResult(
      name: json['name'] as String? ?? 'Subscription',
      durationHours: (json['durationHours'] as num?)?.toDouble() ?? 0.0,
    );
  }
}