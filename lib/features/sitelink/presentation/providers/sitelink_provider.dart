// lib/features/sitelink/presentation/providers/sitelink_provider.dart
// W5.G.3 — SiteLink store state. Loads the agent's SiteLink + its offers + the fleet
// devices, and exposes the management actions the screens drive. Self-registers this
// phone on load so it appears in the device picker.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bingwa_nexus/shared/models/sitelink_model.dart';
import 'package:bingwa_nexus/shared/repositories/sitelink_repository.dart';

@immutable
class SiteLinkState {
  final SiteLink? siteLink;
  final List<SiteLinkOffer> offers;
  final List<FleetDevice> devices;
  final bool isLoading; // initial / full reload
  final bool isBusy; // an action is in flight
  final String? error;

  const SiteLinkState({
    this.siteLink,
    this.offers = const [],
    this.devices = const [],
    this.isLoading = false,
    this.isBusy = false,
    this.error,
  });

  bool get hasSiteLink => siteLink != null;

  SiteLinkState copyWith({
    SiteLink? siteLink,
    List<SiteLinkOffer>? offers,
    List<FleetDevice>? devices,
    bool? isLoading,
    bool? isBusy,
    String? error,
  }) {
    return SiteLinkState(
      siteLink: siteLink ?? this.siteLink,
      offers: offers ?? this.offers,
      devices: devices ?? this.devices,
      isLoading: isLoading ?? this.isLoading,
      isBusy: isBusy ?? this.isBusy,
      error: error,
    );
  }
}

class SiteLinkNotifier extends StateNotifier<SiteLinkState> {
  SiteLinkNotifier(this._repo) : super(const SiteLinkState(isLoading: true)) {
    load();
  }

  final SiteLinkRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    // Best-effort: make sure this phone is registered for the fleet picker.
    unawaited(_repo.registerThisDevice());
    try {
      final sl = await _repo.getMySiteLink();
      if (sl == null) {
        state = const SiteLinkState(isLoading: false);
        return;
      }
      final offers = await _repo.getOffers();
      final devices = await _repo.getDevices();
      state = SiteLinkState(
        siteLink: sl,
        offers: offers,
        devices: devices,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _clean(e));
    }
  }

  Future<bool> checkUsername(String username) => _repo.checkUsername(username);

  Future<bool> createSiteLink({
    required String siteName,
    required String username,
    required SiteLinkAccountType accountType,
    required String accountNumber,
  }) =>
      _run(() async {
        final sl = await _repo.createSiteLink(
          siteName: siteName,
          username: username,
          accountType: accountType,
          accountNumber: accountNumber,
        );
        final devices = await _repo.getDevices();
        state = SiteLinkState(siteLink: sl, devices: devices);
      });

  Future<bool> updateSiteLink(Map<String, dynamic> changes) => _run(() async {
        final sl = await _repo.updateSiteLink(changes);
        state = state.copyWith(siteLink: sl);
      });

  Future<bool> setActive(bool isActive) => _run(() async {
        final sl = await _repo.setActive(isActive);
        state = state.copyWith(siteLink: sl);
      });

  Future<bool> deleteSiteLink() => _run(() async {
        await _repo.deleteSiteLink();
        state = const SiteLinkState();
      });

  Future<bool> addOffer(String offerId) => _run(() async {
        final offers = await _repo.addOffer(offerId);
        state = state.copyWith(offers: offers);
      });

  Future<bool> removeOffer(String siteLinkOfferId) => _run(() async {
        final offers = await _repo.removeOffer(siteLinkOfferId);
        state = state.copyWith(offers: offers);
      });

  Future<bool> setOfferActive(String siteLinkOfferId, bool isActive) =>
      _run(() async {
        final offers = await _repo.setOfferActive(siteLinkOfferId, isActive);
        state = state.copyWith(offers: offers);
      });

  Future<bool> setOfferDevice(String offerId, String? deviceId) => _run(() async {
        final offers = await _repo.setOfferDevice(offerId, deviceId);
        state = state.copyWith(offers: offers);
      });

  Future<void> refreshDevices() async {
    try {
      final devices = await _repo.getDevices();
      state = state.copyWith(devices: devices);
    } catch (_) {
      // non-fatal
    }
  }

  /// Run an action with busy/error handling; returns true on success.
  Future<bool> _run(Future<void> Function() action) async {
    state = state.copyWith(isBusy: true, error: null);
    try {
      await action();
      state = state.copyWith(isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: _clean(e));
      return false;
    }
  }

  String _clean(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        final m = data['message'];
        return m is List ? m.join(', ') : m.toString();
      }
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}

final siteLinkProvider =
    StateNotifierProvider.autoDispose<SiteLinkNotifier, SiteLinkState>((ref) {
  return SiteLinkNotifier(ref.watch(siteLinkRepositoryProvider));
});
