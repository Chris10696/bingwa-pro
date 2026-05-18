// lib/shared/models/subscription_package_model.dart
// W1 new model. Matches backend src/subscriptions/entities/subscription-package.entity.ts.

enum SubscriptionType {
  limited,
  unlimited;

  static SubscriptionType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'LIMITED':
        return SubscriptionType.limited;
      case 'UNLIMITED':
        return SubscriptionType.unlimited;
      default:
        throw ArgumentError('Unknown SubscriptionType: $value');
    }
  }

  String toBackendValue() {
    switch (this) {
      case SubscriptionType.limited:
        return 'LIMITED';
      case SubscriptionType.unlimited:
        return 'UNLIMITED';
    }
  }
}

class SubscriptionPackage {
  final String id;
  final String name;
  final SubscriptionType type;
  // KES, whole shillings.
  final int price;
  final String? description;
  // For LIMITED packages: number of USSD-request tokens. NULL for UNLIMITED.
  final int? tokenAllowance;
  // For UNLIMITED packages: validity duration in milliseconds. NULL for LIMITED.
  final int? durationMs;
  final int sortOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubscriptionPackage({
    required this.id,
    required this.name,
    required this.type,
    required this.price,
    this.description,
    this.tokenAllowance,
    this.durationMs,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubscriptionPackage.fromJson(Map<String, dynamic> json) {
    return SubscriptionPackage(
      id: json['id'] as String,
      name: json['name'] as String,
      type: SubscriptionType.fromString(json['type'] as String),
      price: (json['price'] as num).toInt(),
      description: json['description'] as String?,
      tokenAllowance: (json['tokenAllowance'] as num?)?.toInt(),
      // durationMs comes back as string from Postgres bigint over JSON
      durationMs: json['durationMs'] == null
          ? null
          : (json['durationMs'] is String
              ? int.parse(json['durationMs'] as String)
              : (json['durationMs'] as num).toInt()),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.toBackendValue(),
        'price': price,
        'description': description,
        'tokenAllowance': tokenAllowance,
        'durationMs': durationMs,
        'sortOrder': sortOrder,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}