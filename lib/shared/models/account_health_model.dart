// lib/shared/models/account_health_model.dart
// W5.C — agent account standing (Hybrid AccountHealthStatus). Backend stub returns HEALTHY;
// the full machinery (dial gate + banner) is wired for when a real policy ships.
enum AccountHealthStatus {
  healthy,
  expired,
  paymentPending,
  restricted,
  suspended,
  banned,
  terminated,
  fraudSuspected,
  unknown;

  static AccountHealthStatus fromString(String? v) {
    switch ((v ?? '').toUpperCase()) {
      case 'HEALTHY':
        return AccountHealthStatus.healthy;
      case 'EXPIRED':
        return AccountHealthStatus.expired;
      case 'PAYMENT_PENDING':
        return AccountHealthStatus.paymentPending;
      case 'RESTRICTED':
        return AccountHealthStatus.restricted;
      case 'SUSPENDED':
        return AccountHealthStatus.suspended;
      case 'BANNED':
        return AccountHealthStatus.banned;
      case 'TERMINATED':
        return AccountHealthStatus.terminated;
      case 'FRAUD_SUSPECTED':
        return AccountHealthStatus.fraudSuspected;
      default:
        return AccountHealthStatus.unknown;
    }
  }

  /// Agent-facing restriction message shown on the dashboard banner (empty when fine).
  String get message {
    switch (this) {
      case AccountHealthStatus.healthy:
      case AccountHealthStatus.unknown:
        return '';
      case AccountHealthStatus.paymentPending:
        return 'Payment pending — settle your account to keep selling.';
      case AccountHealthStatus.expired:
        return 'Your subscription has expired. Renew to keep selling.';
      case AccountHealthStatus.restricted:
        return 'Your account access is restricted. Please contact support.';
      case AccountHealthStatus.suspended:
        return 'Your account is suspended. Please contact support.';
      case AccountHealthStatus.banned:
        return 'Your account has been banned. Please contact support.';
      case AccountHealthStatus.terminated:
        return 'Your account has been terminated. Please contact support.';
      case AccountHealthStatus.fraudSuspected:
        return 'Suspicious activity detected. Please contact support.';
    }
  }
}

class AccountHealth {
  final AccountHealthStatus status;
  final DateTime? serverTime;
  const AccountHealth({required this.status, this.serverTime});

  factory AccountHealth.fromJson(Map<String, dynamic> json) => AccountHealth(
        status: AccountHealthStatus.fromString(json['healthStatus'] as String?),
        serverTime: json['serverTime'] != null
            ? DateTime.tryParse(json['serverTime'].toString())
            : null,
      );

  // Fail-open: a healthy or unparseable/unknown status does NOT block selling.
  bool get isHealthy =>
      status == AccountHealthStatus.healthy ||
      status == AccountHealthStatus.unknown;
}
