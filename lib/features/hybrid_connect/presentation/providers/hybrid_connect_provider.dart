// lib/features/hybrid_connect/presentation/providers/hybrid_connect_provider.dart
// W5.F.3 — HybridConnect/Portal screen state.
//
// Bridges the backend Connect-ID endpoints (hybrid_connect_repository) and the native
// socket foreground service (the `bingwa_pro/socket` channel from W5.F.2). The agent
// generates a Connect ID, shares it with the web Portal, and flips the "online" switch
// to start/stop the socket FGS. Live Connected/Disconnected status is polled from native
// via isSocketConnected() — F.2 deliberately added no native→Dart event channel, so a
// short poll drives the status dot (a live EventChannel can replace it later if wanted).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bingwa_nexus/shared/repositories/hybrid_connect_repository.dart';

@immutable
class HybridConnectState {
  final String? connectId;
  final bool isOnline; // the agent has switched the Portal on (socket FGS started)
  final bool isConnected; // the socket is actually live (polled from native)
  final bool isBusy; // a generate / toggle call is in flight
  final String? error;

  const HybridConnectState({
    this.connectId,
    this.isOnline = false,
    this.isConnected = false,
    this.isBusy = false,
    this.error,
  });

  bool get hasConnectId => connectId != null && connectId!.isNotEmpty;

  HybridConnectState copyWith({
    String? connectId,
    bool? isOnline,
    bool? isConnected,
    bool? isBusy,
    String? error,
  }) {
    return HybridConnectState(
      connectId: connectId ?? this.connectId,
      isOnline: isOnline ?? this.isOnline,
      isConnected: isConnected ?? this.isConnected,
      isBusy: isBusy ?? this.isBusy,
      error: error,
    );
  }
}

class HybridConnectNotifier extends StateNotifier<HybridConnectState> {
  HybridConnectNotifier(this._repo) : super(const HybridConnectState()) {
    _init();
  }

  final HybridConnectRepository _repo;
  static const MethodChannel _socket = MethodChannel('bingwa_pro/socket');
  Timer? _poll;

  Future<void> _init() async {
    try {
      final id = await _repo.getConnectId();
      final connected = await _isConnected();
      state = state.copyWith(
        connectId: id,
        isConnected: connected,
        isOnline: connected,
      );
    } catch (_) {
      // Non-fatal: the agent can still generate. Leave state as-is.
    }
    _poll = Timer.periodic(
        const Duration(seconds: 2), (_) => _refreshConnected());
  }

  Future<bool> _isConnected() async {
    try {
      return await _socket.invokeMethod<bool>('isSocketConnected') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _refreshConnected() async {
    final connected = await _isConnected();
    if (connected != state.isConnected) {
      state = state.copyWith(isConnected: connected);
    }
  }

  /// Generate (or reuse) the Connect ID via the backend.
  Future<void> generate() async {
    state = state.copyWith(isBusy: true, error: null);
    try {
      final id = await _repo.generateConnectId();
      state = state.copyWith(connectId: id, isBusy: false);
    } catch (e) {
      state = state.copyWith(isBusy: false, error: _clean(e));
    }
  }

  /// Master "online" switch: ON starts the socket FGS for the Connect ID (generating
  /// one first if needed); OFF stops it.
  Future<void> setOnline(bool on) async {
    state = state.copyWith(isBusy: true, error: null);
    try {
      if (on) {
        final id = state.connectId ?? await _repo.generateConnectId();
        await _socket.invokeMethod('startSocket', {'connectId': id});
        state = state.copyWith(connectId: id, isOnline: true, isBusy: false);
      } else {
        await _socket.invokeMethod('stopSocket');
        state = state.copyWith(
            isOnline: false, isConnected: false, isBusy: false);
      }
    } catch (e) {
      state = state.copyWith(isBusy: false, error: _clean(e));
    }
  }

  String _clean(Object e) =>
      e.toString().replaceFirst('Exception: ', '');

  @override
  void dispose() {
    // NOTE: we intentionally do NOT stop the socket here — the Portal is meant to keep
    // running in the background after the screen closes. Only the status poll stops.
    _poll?.cancel();
    super.dispose();
  }
}

final hybridConnectProvider = StateNotifierProvider.autoDispose<
    HybridConnectNotifier, HybridConnectState>((ref) {
  return HybridConnectNotifier(ref.watch(hybridConnectRepositoryProvider));
});
