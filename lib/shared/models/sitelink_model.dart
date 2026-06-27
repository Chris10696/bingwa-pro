// lib/shared/models/sitelink_model.dart
// W5.G.3 — SiteLink store models (hand-written, matching the backend src/sitelink shapes).
enum SiteLinkAccountType {
  till,
  mpesa;

  static SiteLinkAccountType fromString(String? v) {
    switch ((v ?? '').toUpperCase()) {
      case 'MPESA':
        return SiteLinkAccountType.mpesa;
      case 'TILL':
      default:
        return SiteLinkAccountType.till;
    }
  }

  /// Wire value sent to the backend enum.
  String get wire => this == SiteLinkAccountType.mpesa ? 'MPESA' : 'TILL';

  /// Agent-facing label.
  String get label => this == SiteLinkAccountType.mpesa ? 'M-Pesa' : 'Till';
}

class SiteLink {
  final String id;
  final String siteName;
  final String username;
  final String url;
  final SiteLinkAccountType accountType;
  final String accountNumber;
  final bool isActive;

  const SiteLink({
    required this.id,
    required this.siteName,
    required this.username,
    required this.url,
    required this.accountType,
    required this.accountNumber,
    required this.isActive,
  });

  factory SiteLink.fromJson(Map<String, dynamic> j) => SiteLink(
        id: j['id'] as String,
        siteName: j['siteName'] as String? ?? '',
        username: j['username'] as String? ?? '',
        url: j['url'] as String? ?? '',
        accountType: SiteLinkAccountType.fromString(j['accountType'] as String?),
        accountNumber: j['accountNumber'] as String? ?? '',
        isActive: j['isActive'] as bool? ?? false,
      );
}

class SiteLinkOffer {
  final String siteLinkOfferId;
  final String offerId;
  final String name;
  final String ussdCode;
  final int price;
  final String type; // OfferType: DATA / VOICE / SMS / NONE
  final bool isActive;
  final String? relayDevice;

  const SiteLinkOffer({
    required this.siteLinkOfferId,
    required this.offerId,
    required this.name,
    required this.ussdCode,
    required this.price,
    required this.type,
    required this.isActive,
    this.relayDevice,
  });

  factory SiteLinkOffer.fromJson(Map<String, dynamic> j) => SiteLinkOffer(
        siteLinkOfferId: j['siteLinkOfferId'] as String,
        offerId: j['offerId'] as String,
        name: j['name'] as String? ?? '',
        ussdCode: j['ussdCode'] as String? ?? '',
        price: (j['price'] as num?)?.toInt() ?? 0,
        type: j['type'] as String? ?? 'DATA',
        isActive: j['isActive'] as bool? ?? true,
        relayDevice: j['relayDevice'] as String?,
      );
}

/// One of the agent's registered phones (fleet picker).
class FleetDevice {
  final String id;
  final String deviceId;
  final String? deviceModel;
  final String? connectId;
  final String? appState;
  final DateTime? lastSeenAt;

  const FleetDevice({
    required this.id,
    required this.deviceId,
    this.deviceModel,
    this.connectId,
    this.appState,
    this.lastSeenAt,
  });

  factory FleetDevice.fromJson(Map<String, dynamic> j) => FleetDevice(
        id: j['id'] as String,
        deviceId: j['deviceId'] as String,
        deviceModel: j['deviceModel'] as String?,
        connectId: j['connectId'] as String?,
        appState: j['appState'] as String?,
        lastSeenAt: j['lastSeenAt'] != null
            ? DateTime.tryParse(j['lastSeenAt'].toString())
            : null,
      );

  String get label =>
      (deviceModel != null && deviceModel!.isNotEmpty) ? deviceModel! : deviceId;
}
