// lib/shared/repositories/sitelink_repository.dart
// W5.G.3 — SiteLink store client. Wraps the backend src/sitelink endpoints (auth via the
// dio AuthInterceptor) and self-registers this phone so it appears in the fleet picker.
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/dio_client.dart';
import '../models/sitelink_model.dart';

class SiteLinkRepository {
  final Dio _dio;
  SiteLinkRepository(this._dio);

  // ── SiteLink ──────────────────────────────────────────────────────────────────────
  /// The agent's SiteLink, or null if they haven't created one yet.
  Future<SiteLink?> getMySiteLink() async {
    final res = await _dio.get('/sitelink');
    final data = res.data;
    if (data is! Map || data['id'] == null) return null;
    return SiteLink.fromJson(data.cast<String, dynamic>());
  }

  Future<bool> checkUsername(String username) async {
    final res = await _dio.get('/sitelink/username-availability/$username');
    final data = res.data;
    return data is Map ? (data['available'] as bool? ?? false) : false;
  }

  Future<SiteLink> createSiteLink({
    required String siteName,
    required String username,
    required SiteLinkAccountType accountType,
    required String accountNumber,
  }) async {
    final res = await _dio.post('/sitelink', data: {
      'siteName': siteName,
      'username': username,
      'accountType': accountType.wire,
      'accountNumber': accountNumber,
    });
    return SiteLink.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<SiteLink> updateSiteLink(Map<String, dynamic> changes) async {
    final res = await _dio.patch('/sitelink', data: changes);
    return SiteLink.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<SiteLink> setActive(bool isActive) async {
    final res = await _dio.patch('/sitelink/active', data: {'isActive': isActive});
    return SiteLink.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<void> deleteSiteLink() async {
    await _dio.delete('/sitelink');
  }

  // ── SiteLink offers ─────────────────────────────────────────────────────────────────
  Future<List<SiteLinkOffer>> getOffers() async =>
      _offers((await _dio.get('/sitelink/offers')).data);

  Future<List<SiteLinkOffer>> addOffer(String offerId) async =>
      _offers((await _dio.post('/sitelink/offers', data: {'offerId': offerId})).data);

  Future<List<SiteLinkOffer>> setOfferActive(
          String siteLinkOfferId, bool isActive) async =>
      _offers((await _dio.patch('/sitelink/offers/$siteLinkOfferId',
              data: {'isActive': isActive}))
          .data);

  Future<List<SiteLinkOffer>> removeOffer(String siteLinkOfferId) async =>
      _offers((await _dio.delete('/sitelink/offers/$siteLinkOfferId')).data);

  /// Assign which device dials this offer; pass null to clear.
  Future<List<SiteLinkOffer>> setOfferDevice(
          String offerId, String? deviceId) async =>
      _offers((await _dio.patch('/sitelink/offers/$offerId/relay-device',
              data: {'relayDevice': deviceId ?? ''}))
          .data);

  List<SiteLinkOffer> _offers(dynamic data) {
    if (data is! List) return const [];
    return data
        .map((e) => SiteLinkOffer.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ── Devices (fleet picker) ──────────────────────────────────────────────────────────
  Future<List<FleetDevice>> getDevices() async {
    final data = (await _dio.get('/sitelink/devices')).data;
    if (data is! List) return const [];
    return data
        .map((e) => FleetDevice.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Best-effort: register THIS phone so it shows in the agent's fleet picker.
  Future<void> registerThisDevice() async {
    try {
      final deviceId = await _stableDeviceId();
      String? model;
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        model = '${info.manufacturer} ${info.model}'.trim();
      } catch (_) {
        // device_info unavailable — register with the id alone.
      }
      await _dio.post('/sitelink/devices', data: {
        'deviceId': deviceId,
        if (model != null && model.isNotEmpty) 'deviceModel': model,
      });
    } catch (_) {
      // Non-fatal: the picker still works with whatever's already registered.
    }
  }

  // device_info_plus 12.x no longer exposes a stable ANDROID_ID, so we persist a
  // generated id once per install (stable per phone for this agent's fleet).
  static const _deviceIdKey = 'nexus_device_id';
  Future<String> _stableDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = List.generate(
        16,
        (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }
}

final siteLinkRepositoryProvider = Provider<SiteLinkRepository>((ref) {
  return SiteLinkRepository(ref.watch(dioClientProvider));
});
