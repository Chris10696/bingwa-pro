// lib/shared/models/offer_model.dart
// W2.A: reshaped to match backend offer.entity.ts.
//   - ussdTemplate → ussdCode (D-W2-F)
//   - dropped validityLabel (D-W2-3), categoryId + OfferCategory (D-W2-1)
//   - added type (OfferType enum) + 8 Hybrid retry/reschedule fields (Q-W2-1)
// W5.A: re-added commissionRate (agent commission % of the sale).
// OfferType display labels: NONE→"All", DATA→"Data", VOICE→"Minutes", SMS→"SMS".

enum OfferType {
  none,
  voice,
  data,
  sms;

  static OfferType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'NONE':
        return OfferType.none;
      case 'VOICE':
        return OfferType.voice;
      case 'DATA':
        return OfferType.data;
      case 'SMS':
        return OfferType.sms;
      default:
        return OfferType.data;
    }
  }

  String toBackendValue() {
    switch (this) {
      case OfferType.none:
        return 'NONE';
      case OfferType.voice:
        return 'VOICE';
      case OfferType.data:
        return 'DATA';
      case OfferType.sms:
        return 'SMS';
    }
  }

  /// UI display label. VOICE shows as "Minutes" to match Hybrid's UI.
  String get displayLabel {
    switch (this) {
      case OfferType.none:
        return 'All';
      case OfferType.voice:
        return 'Minutes';
      case OfferType.data:
        return 'Data';
      case OfferType.sms:
        return 'SMS';
    }
  }
}

/// Per-offer dial-mode override (client request). null = use the agent's global mode.
enum OfferProcessingMode {
  express,
  advanced;

  static OfferProcessingMode? fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'EXPRESS':
        return OfferProcessingMode.express;
      case 'ADVANCED':
        return OfferProcessingMode.advanced;
      default:
        return null;
    }
  }

  String toBackendValue() =>
      this == OfferProcessingMode.advanced ? 'ADVANCED' : 'EXPRESS';

  /// Native dial-path value (UssdExecutionService compares lowercase).
  String get wire => this == OfferProcessingMode.advanced ? 'advanced' : 'express';

  String get displayLabel =>
      this == OfferProcessingMode.advanced ? 'Advanced' : 'Express';
}

class Offer {
  final String id;
  final String name;
  // USSD code with BH placeholder for the customer phone (e.g. *180*5*2*BH*1*1#).
  final String ussdCode;
  // KES whole shillings.
  final int price;
  final OfferType type;
  // Per-offer Express/Advanced override; null = use the agent's global processing mode.
  final OfferProcessingMode? processingMode;
  final bool isActive;
  final String agentId;
  // W5.A — agent commission as a PERCENT of the sale (0–100); 0 = no commission.
  final double commissionRate;

  // Hybrid retry/reschedule config (Q-W2-1, data layer only in W2).
  final bool autoReschedule;
  final String? autoRescheduleRunTime;
  final bool autoRetry;
  final bool autoRetryConnectionProblems;
  final int numberOfRetries;
  final int retryIntervalMins;
  final String? relayDevice;
  final int ussdTimeoutMillis;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Offer({
    required this.id,
    required this.name,
    required this.ussdCode,
    required this.price,
    required this.type,
    this.processingMode,
    required this.isActive,
    required this.agentId,
    this.commissionRate = 0,
    this.autoReschedule = false,
    this.autoRescheduleRunTime,
    this.autoRetry = false,
    this.autoRetryConnectionProblems = false,
    this.numberOfRetries = 0,
    this.retryIntervalMins = 5,
    this.relayDevice,
    this.ussdTimeoutMillis = 60000,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      id: json['id'] as String,
      name: json['name'] as String,
      ussdCode: json['ussdCode'] as String,
      price: (json['price'] as num).toInt(),
      type: OfferType.fromString(json['type'] as String? ?? 'DATA'),
      processingMode:
          OfferProcessingMode.fromString(json['processingMode'] as String?),
      isActive: json['isActive'] as bool? ?? true,
      agentId: json['agentId'] as String,
      commissionRate: (json['commissionRate'] as num?)?.toDouble() ?? 0,
      autoReschedule: json['autoReschedule'] as bool? ?? false,
      autoRescheduleRunTime: json['autoRescheduleRunTime'] as String?,
      autoRetry: json['autoRetry'] as bool? ?? false,
      autoRetryConnectionProblems:
          json['autoRetryConnectionProblems'] as bool? ?? false,
      numberOfRetries: (json['numberOfRetries'] as num?)?.toInt() ?? 0,
      retryIntervalMins: (json['retryIntervalMins'] as num?)?.toInt() ?? 5,
      relayDevice: json['relayDevice'] as String?,
      ussdTimeoutMillis:
          (json['ussdTimeoutMillis'] as num?)?.toInt() ?? 60000,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ussdCode': ussdCode,
        'price': price,
        'type': type.toBackendValue(),
        'processingMode': processingMode?.toBackendValue(),
        'isActive': isActive,
        'agentId': agentId,
        'commissionRate': commissionRate,
        'autoReschedule': autoReschedule,
        'autoRescheduleRunTime': autoRescheduleRunTime,
        'autoRetry': autoRetry,
        'autoRetryConnectionProblems': autoRetryConnectionProblems,
        'numberOfRetries': numberOfRetries,
        'retryIntervalMins': retryIntervalMins,
        'relayDevice': relayDevice,
        'ussdTimeoutMillis': ussdTimeoutMillis,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Offer copyWith({
    String? id,
    String? name,
    String? ussdCode,
    int? price,
    OfferType? type,
    OfferProcessingMode? processingMode,
    bool? isActive,
    String? agentId,
    double? commissionRate,
    bool? autoReschedule,
    String? autoRescheduleRunTime,
    bool? autoRetry,
    bool? autoRetryConnectionProblems,
    int? numberOfRetries,
    int? retryIntervalMins,
    String? relayDevice,
    int? ussdTimeoutMillis,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Offer(
      id: id ?? this.id,
      name: name ?? this.name,
      ussdCode: ussdCode ?? this.ussdCode,
      price: price ?? this.price,
      type: type ?? this.type,
      processingMode: processingMode ?? this.processingMode,
      isActive: isActive ?? this.isActive,
      agentId: agentId ?? this.agentId,
      commissionRate: commissionRate ?? this.commissionRate,
      autoReschedule: autoReschedule ?? this.autoReschedule,
      autoRescheduleRunTime:
          autoRescheduleRunTime ?? this.autoRescheduleRunTime,
      autoRetry: autoRetry ?? this.autoRetry,
      autoRetryConnectionProblems:
          autoRetryConnectionProblems ?? this.autoRetryConnectionProblems,
      numberOfRetries: numberOfRetries ?? this.numberOfRetries,
      retryIntervalMins: retryIntervalMins ?? this.retryIntervalMins,
      relayDevice: relayDevice ?? this.relayDevice,
      ussdTimeoutMillis: ussdTimeoutMillis ?? this.ussdTimeoutMillis,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
