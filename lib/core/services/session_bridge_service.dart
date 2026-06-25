// lib/core/services/session_bridge_service.dart
//
// W3.E / D-W3-19 (Option B — native session bridge).
//
// Thin wrapper over the `bingwa_pro/session` MethodChannel. The background
// worker (ScheduleTransactionWorker) runs with no Flutter engine, so it cannot
// read flutter_secure_storage. Dart therefore MIRRORS the current session into a
// small native prefs store (SessionBridge.kt) and the worker reads the *current*
// token each time it fires — nothing stale ever gets baked into a scheduled job.
//
// WIRING (B6 — not yet done): call [setSession] right after a successful login
// AND on every token refresh (auth_provider / session_manager), and [clear] on
// logout. Until those call sites exist, the native store stays empty and the
// worker will Result.retry() instead of firing — by design.
//
// This same bridge is the foundation W3.J's 24/7 refresh heartbeat will reuse.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionBridgeService {
  static const MethodChannel _channel = MethodChannel('bingwa_pro/session');

  /// Mirror the current session to native. Call on login + every token refresh.
  /// [baseUrl] is the *runtime* base URL (so a --dart-define Railway override is
  /// honoured by the worker, not the compiled default).
  Future<void> setSession({
    required String accessToken,
    required String baseUrl,
    required String agentId,
  }) async {
    try {
      await _channel.invokeMethod<bool>('setSession', <String, dynamic>{
        'accessToken': accessToken,
        'baseUrl': baseUrl,
        'agentId': agentId,
      });
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.setSession failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.setSession channel unavailable: ${e.message}');
    }
  }

  /// Clear the mirrored session. Call on logout / session invalidation.
  Future<void> clear() async {
    try {
      await _channel.invokeMethod<bool>('clearSession');
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.clear failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.clear channel unavailable: ${e.message}');
    }
  }

  /// W3.C: mirror the agent's processing mode ('express' | 'advanced') to native.
  /// The native dial path (UssdExecutionService) and UssdAccessibilityService read
  /// this to choose Express vs Advanced dialing without a Flutter engine or network.
  ///
  /// WIRING (W3.I): call this when the processing-mode radio changes and after the
  /// wallet (which owns processingMode) syncs. Until then the native store defaults to
  /// 'express', so all dials stay Express — identical to today.
  Future<void> saveProcessingMode(String mode) async {
    try {
      await _channel.invokeMethod<bool>('saveProcessingMode', <String, dynamic>{
        'mode': mode,
      });
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.saveProcessingMode failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.saveProcessingMode channel unavailable: ${e.message}');
    }
  }

  /// W3.I: true iff our UssdAccessibilityService is currently enabled in system
  /// settings. Used to gate/reconcile Advanced mode — if the wallet says Advanced
  /// but this is false, the caller reverts to Express (matching Hybrid). Returns
  /// false on any channel error (fail safe → treat as not-enabled).
  Future<bool> isAccessibilityEnabled() async {
    try {
      final enabled =
          await _channel.invokeMethod<bool>('isAccessibilityEnabled');
      return enabled ?? false;
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.isAccessibilityEnabled failed: ${e.message}');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.isAccessibilityEnabled channel unavailable: ${e.message}');
      return false;
    }
  }

  /// W3.I: open the system Accessibility settings page (the "Open Accessibility
  /// Settings" button on the AccessibilityRequired screen). Fires
  /// Settings.ACTION_ACCESSIBILITY_SETTINGS natively.
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod<bool>('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.openAccessibilitySettings failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.openAccessibilitySettings channel unavailable: ${e.message}');
    }
  }

  /// W3.K: mirror the "Process M-Pesa Messages" toggle to native. The SMS
  /// receiver reads this (AND-ed with AppState==running) to decide whether to
  /// auto-process an incoming M-Pesa payment. Default native value is true
  /// (Hybrid parity); call this whenever the settings toggle changes / syncs.
  Future<void> saveProcessMpesa(bool enabled) =>
      _saveProcessFlag('saveProcessMpesa', enabled);

  /// W4: mirror the "Process Till" / "Process SiteLink" toggles to native. Same gate shape as
  /// M-Pesa (AND-ed with AppState==running, per type). Till defaults ON, SiteLink OFF (inert
  /// until the W5 SiteLink store exists).
  Future<void> saveProcessTill(bool enabled) =>
      _saveProcessFlag('saveProcessTill', enabled);
  Future<void> saveProcessSiteLink(bool enabled) =>
      _saveProcessFlag('saveProcessSiteLink', enabled);

  Future<void> _saveProcessFlag(String method, bool enabled) async {
    try {
      await _channel.invokeMethod<bool>(method, <String, dynamic>{'enabled': enabled});
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.$method failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.$method channel unavailable: ${e.message}');
    }
  }

  /// W4: current state of the three message-processing toggles, for the Settings load.
  /// Native defaults: M-Pesa ON, Till ON, SiteLink OFF.
  Future<bool> getProcessMpesa() => _getProcessFlag('getProcessMpesa', true);
  Future<bool> getProcessTill() => _getProcessFlag('getProcessTill', true);
  Future<bool> getProcessSiteLink() => _getProcessFlag('getProcessSiteLink', false);

  Future<bool> _getProcessFlag(String method, bool fallback) async {
    try {
      final v = await _channel.invokeMethod<bool>(method);
      return v ?? fallback;
    } on PlatformException {
      return fallback;
    } on MissingPluginException {
      return fallback;
    }
  }

  // ── W4: Authorized Senders (agent-managed, on-device). Extends the built-in M-Pesa fence. ──

  /// Current authorized senders (may be empty).
  Future<List<String>> getAuthorizedSenders() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getAuthorizedSenders');
      return raw?.map((e) => e.toString()).toList() ?? <String>[];
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.getAuthorizedSenders failed: ${e.message}');
      return <String>[];
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.getAuthorizedSenders unavailable: ${e.message}');
      return <String>[];
    }
  }

  /// Add a sender; returns true if newly added, false if blank/duplicate/unavailable.
  Future<bool> addAuthorizedSender(String sender) async {
    try {
      final added = await _channel
          .invokeMethod<bool>('addAuthorizedSender', <String, dynamic>{'sender': sender});
      return added ?? false;
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.addAuthorizedSender failed: ${e.message}');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.addAuthorizedSender unavailable: ${e.message}');
      return false;
    }
  }

  Future<void> removeAuthorizedSender(String sender) async {
    try {
      await _channel
          .invokeMethod<bool>('removeAuthorizedSender', <String, dynamic>{'sender': sender});
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.removeAuthorizedSender failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.removeAuthorizedSender unavailable: ${e.message}');
    }
  }

  // ── W4-batch-4: Auto-Save Contacts toggle (native writes the customer to the phonebook). ──
  Future<void> saveAutoSaveContacts(bool enabled) =>
      _saveProcessFlag('saveAutoSaveContacts', enabled);
  Future<bool> getAutoSaveContacts() =>
      _getProcessFlag('getAutoSaveContacts', false);

  // ── W4-batch-5: Auto-Reply templates (on-device store; one per AutoReplyType). ──
  /// Returns [{type, message, isActive}] for all six auto-reply types.
  Future<List<Map<String, dynamic>>> getAutoReplies() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getAutoReplies');
      return raw
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          <Map<String, dynamic>>[];
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.getAutoReplies failed: ${e.message}');
      return <Map<String, dynamic>>[];
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.getAutoReplies unavailable: ${e.message}');
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> saveAutoReply({
    required String type,
    required String message,
    required bool isActive,
  }) async {
    try {
      await _channel.invokeMethod<bool>('saveAutoReply', <String, dynamic>{
        'type': type,
        'message': message,
        'isActive': isActive,
      });
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.saveAutoReply failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.saveAutoReply unavailable: ${e.message}');
    }
  }

  /// W3.N: mirror the engine's AppState ('stopped' | 'running' | 'paused') to
  /// native. This is the master switch the dashboard play/pause/stop writes; the
  /// SMS receiver auto-processes only when AppState=='running', and the dialer
  /// reacts to it. Hybrid's DefaultAppControl is pure state (persist + flow), so
  /// mirroring the string here is the whole native side.
  Future<void> saveAppState(String state) async {
    try {
      await _channel.invokeMethod<bool>('saveAppState', <String, dynamic>{
        'state': state,
      });
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.saveAppState failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.saveAppState channel unavailable: ${e.message}');
    }
  }

  // ── W3.F: SIM routing mirror + active-SIM info ──────────────────────────────
  // The SIM-setup screen calls these to mirror the agent's SIM choices to native
  // (read by SimSubscriptionResolver on the dial/SMS paths) and to render real SIMs.

  Future<void> _saveSimBool(String method, bool enabled) async {
    try {
      await _channel.invokeMethod<bool>(method, <String, dynamic>{'enabled': enabled});
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.$method failed: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.$method channel unavailable: ${e.message}');
    }
  }

  Future<void> saveDialUssdViaSim2(bool enabled) =>
      _saveSimBool('saveDialUssdViaSim2', enabled);
  Future<void> saveSendSmsViaSim2(bool enabled) =>
      _saveSimBool('saveSendSmsViaSim2', enabled);
  Future<void> saveReceivePaymentsViaSim1(bool enabled) =>
      _saveSimBool('saveReceivePaymentsViaSim1', enabled);
  Future<void> saveReceivePaymentsViaSim2(bool enabled) =>
      _saveSimBool('saveReceivePaymentsViaSim2', enabled);

  /// Active SIMs as [{slot:int, label:String}] for the SIM-setup screen.
  /// Empty on any channel error or when READ_PHONE_STATE is unavailable.
  Future<List<Map<String, dynamic>>> getSimInfo() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getSimInfo');
      if (raw == null) return const [];
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(growable: false);
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.getSimInfo failed: ${e.message}');
      return const [];
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.getSimInfo channel unavailable: ${e.message}');
      return const [];
    }
  }

  /// W3.L: hand a SCHEDULED Quick Dial transaction to the native pipeline
  /// (UssdExecutionService). The native side reads token/baseUrl from the
  /// mirrored session, builds a DialRequest, and enqueues — identical pipeline
  /// to SMS/scheduled dials (Express/Advanced per mode, classify, retry,
  /// auto-reply, status PATCH). Returns true if the enqueue was accepted.
  ///
  /// [offerName]/[offerPrice] feed the W3.M SUCCESS auto-reply; Quick Dial has
  /// no M-Pesa sender, so customerName/mpesaCode are intentionally absent.
  Future<bool> enqueueQuickDial({
    required String transactionId,
    required String ussdCode,
    required String customerPhone,
    String? offerId,
    String? offerName,
    int? amount,
    int? offerPrice,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('enqueueQuickDial', {
        'transactionId': transactionId,
        'ussdCode': ussdCode,
        'customerPhone': customerPhone,
        'offerId': offerId,
        'offerName': offerName,
        'amount': amount,
        'offerPrice': offerPrice,
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('SessionBridgeService.enqueueQuickDial failed: ${e.message}');
      return false;
    } on MissingPluginException catch (e) {
      debugPrint('SessionBridgeService.enqueueQuickDial channel unavailable: ${e.message}');
      return false;
    }
  }
}

final sessionBridgeServiceProvider =
    Provider<SessionBridgeService>((ref) => SessionBridgeService());