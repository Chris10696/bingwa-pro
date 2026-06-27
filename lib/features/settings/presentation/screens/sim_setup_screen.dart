// lib/features/settings/presentation/screens/sim_setup_screen.dart
//
// W3.F — SIM Setup (mirrors Bingwa Hybrid's SimSetup screen, Image 2).
//
// Three sections, each with a SIM 1 and SIM 2 control:
//   1. "SIM to receive payments"      — INDEPENDENT switches (a set; either/both/neither).
//                                        → RECEIVE_PAYMENTS_VIA_SIM_1 / _SIM_2 booleans.
//   2. "Bingwa SIM (To run USSDs)"     — EXCLUSIVE (radio): exactly one of SIM 1 / SIM 2.
//                                        → DIAL_USSD_VIA_SIM_2 (false = SIM 1, true = SIM 2).
//   3. "Send Auto-Replies Using"       — EXCLUSIVE (radio): exactly one of SIM 1 / SIM 2.
//                                        → SEND_SMS_VIA_SIM_2 (false = SIM 1, true = SIM 2).
//
// All choices mirror to native (SessionBridge) where SimSubscriptionResolver reads them on
// the dial / SMS-send / receive-gate paths. SIM labels come from the native getSimInfo
// channel (active carrier display names); slots without an active SIM are shown disabled.
//
// BRING-UP HARDENING (SIM-not-detected):
//   getActiveSubscriptionInfoList() needs READ_PHONE_STATE, and on Android 14 a missing grant
//   returns an EMPTY LIST SILENTLY (no exception). The old screen never requested the
//   permission and showed one ambiguous banner, so an agent had no in-app way to recover.
//   Now the screen:
//     • requests Phone permission on entry (real prompt, via permission_handler),
//     • separates "permission denied" (Grant button) from "granted but no SIM" (insert-SIM note),
//     • offers Open Settings on a permanent denial,
//     • re-checks automatically when the app resumes (so a Settings grant clears it without
//       leaving/re-entering) and via a manual refresh in the app bar.
//   The native SimSubscriptionResolver is unchanged — disambiguation happens here.
//
// NOTE: requires the `permission_handler` package. If it isn't already a dependency, add it:
//   flutter pub add permission_handler
// READ_PHONE_STATE is already declared in AndroidManifest.xml, so no manifest change is needed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/session_bridge_service.dart';

/// Phone-permission state for the SIM-setup flow.
enum _PermState { checking, granted, denied, permanentlyDenied }

class SimSetupScreen extends ConsumerStatefulWidget {
  const SimSetupScreen({super.key});

  @override
  ConsumerState<SimSetupScreen> createState() => _SimSetupScreenState();
}

class _SimSetupScreenState extends ConsumerState<SimSetupScreen>
    with WidgetsBindingObserver {
  static const _green = Color(0xFF00C853);

  // Native getters live on the same session channel; the service exposes setters +
  // getSimInfo. For the initial toggle state we read the booleans directly here.
  static const MethodChannel _channel = MethodChannel('bingwa_pro/session');

  bool _loading = true;

  // Phone-permission state (drives whether we show the prompt or the SIM sections).
  _PermState _perm = _PermState.checking;

  // Active SIM labels by slot (1-based). Absent slot → no active SIM.
  final Map<int, String> _simLabels = {};

  // Receive-payments (independent).
  bool _receiveSim1 = true;
  bool _receiveSim2 = false;

  // Dial (radio): false = SIM 1, true = SIM 2.
  bool _dialViaSim2 = false;

  // Auto-reply (radio): false = SIM 1, true = SIM 2.
  bool _replyViaSim2 = false;

  SessionBridgeService get _bridge => ref.read(sessionBridgeServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the agent left to grant the permission in Settings, re-check on return
    // so the screen recovers without a manual leave/re-enter. We only re-check
    // (never re-prompt) here to avoid a prompt loop on every resume.
    if (state == AppLifecycleState.resumed && _perm != _PermState.granted) {
      _recheckOnResume();
    }
  }

  Future<void> _recheckOnResume() async {
    final status = await Permission.phone.status;
    if (!mounted) return;
    if (status.isGranted) {
      setState(() {
        _perm = _PermState.granted;
        _loading = true;
      });
      await _loadSimData();
    } else {
      setState(() {
        _perm = status.isPermanentlyDenied
            ? _PermState.permanentlyDenied
            : _PermState.denied;
      });
    }
  }

  /// Entry / retry: ensure Phone permission, then load SIM data if granted.
  Future<void> _load() async {
    var status = await Permission.phone.status;
    // `denied` covers both "never asked" and "asked, can ask again" → prompt now.
    if (status.isDenied) {
      status = await Permission.phone.request();
    }
    if (!mounted) return;
    if (status.isGranted) {
      setState(() => _perm = _PermState.granted);
      await _loadSimData();
      return;
    }
    setState(() {
      _perm = status.isPermanentlyDenied
          ? _PermState.permanentlyDenied
          : _PermState.denied;
      _loading = false;
    });
  }

  /// Reads active SIM labels + the stored SIM-routing booleans from native.
  Future<void> _loadSimData() async {
    _simLabels.clear();
    // SIM labels (best-effort).
    final sims = await _bridge.getSimInfo();
    for (final s in sims) {
      final slot = s['slot'] as int?;
      final label = s['label'] as String?;
      if (slot != null) _simLabels[slot] = label ?? 'SIM $slot';
    }
    // Current booleans from native (defaults match a fresh single-SIM install).
    _receiveSim1 = await _getBool('getReceivePaymentsViaSim1', true);
    _receiveSim2 = await _getBool('getReceivePaymentsViaSim2', false);
    _dialViaSim2 = await _getBool('getDialUssdViaSim2', false);
    _replyViaSim2 = await _getBool('getSendSmsViaSim2', false);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    await _load();
  }

  Future<bool> _getBool(String method, bool fallback) async {
    try {
      final v = await _channel.invokeMethod<bool>(method);
      return v ?? fallback;
    } on PlatformException {
      return fallback;
    } on MissingPluginException {
      return fallback;
    }
  }

  bool _slotActive(int slot) => _simLabels.containsKey(slot);

  /// Primary row label — always "SIM 1" / "SIM 2" (Hybrid parity). The agent must
  /// be able to tell the two slots apart to assign roles; the carrier name alone
  /// can't do that when both SIMs are Safaricom (the bug this screen had).
  String _slotName(int slot) => 'SIM $slot';

  /// Secondary line — the active carrier (e.g. "Safaricom"), or a not-detected note
  /// so a slot with no SIM is still legible. A minor, helpful divergence from Hybrid
  /// (which shows only "SIM 1"/"SIM 2"): it ties the slot to the physical SIM.
  String _carrierSubtitle(int slot) =>
      _slotActive(slot) ? (_simLabels[slot] ?? 'Active') : 'Not detected';

  // ── Receive (independent) ───────────────────────────────────────────────
  void _onReceiveChanged(int slot, bool value) {
    setState(() {
      if (slot == 1) {
        _receiveSim1 = value;
      } else {
        _receiveSim2 = value;
      }
    });
    if (slot == 1) {
      _bridge.saveReceivePaymentsViaSim1(value);
    } else {
      _bridge.saveReceivePaymentsViaSim2(value);
    }
  }

  // ── Dial (radio) ────────────────────────────────────────────────────────
  void _onDialSelected(int slot) {
    final via2 = slot == 2;
    setState(() => _dialViaSim2 = via2);
    _bridge.saveDialUssdViaSim2(via2);
  }

  // ── Reply (radio) ───────────────────────────────────────────────────────
  void _onReplySelected(int slot) {
    final via2 = slot == 2;
    setState(() => _replyViaSim2 = via2);
    _bridge.saveSendSmsViaSim2(via2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Sim Setup'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        actions: [
          if (!_loading && _perm == _PermState.granted)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Re-check SIMs',
              onPressed: _retry,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (_perm == _PermState.denied || _perm == _PermState.permanentlyDenied) {
      return _permissionPrompt();
    }
    // Permission granted → show the sections (with a no-SIM note if applicable).
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_simLabels.isEmpty) _noSimCard(),
        _section(
          title: 'SIM to receive payments',
          children: [
            _simSwitchRow(1, _receiveSim1, (v) => _onReceiveChanged(1, v)),
            _simSwitchRow(2, _receiveSim2, (v) => _onReceiveChanged(2, v)),
          ],
        ),
        const SizedBox(height: 24),
        _section(
          title: 'Bingwa SIM (To run USSDs)',
          children: [
            _simExclusiveSwitchRow(1, !_dialViaSim2, () => _onDialSelected(1)),
            _simExclusiveSwitchRow(2, _dialViaSim2, () => _onDialSelected(2)),
          ],
        ),
        const SizedBox(height: 24),
        _section(
          title: 'Send Auto-Replies Using',
          children: [
            _simExclusiveSwitchRow(1, !_replyViaSim2, () => _onReplySelected(1)),
            _simExclusiveSwitchRow(2, _replyViaSim2, () => _onReplySelected(2)),
          ],
        ),
      ],
    );
  }

  // Shown when Phone permission is denied / permanently denied.
  Widget _permissionPrompt() {
    final permanent = _perm == _PermState.permanentlyDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sim_card_alert_outlined,
                size: 64, color: Colors.orange.shade400),
            const SizedBox(height: 16),
            const Text(
              'Phone permission needed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              permanent
                  ? 'Bingwa Nexus needs the Phone permission to detect your SIM '
                      'cards. It looks like it was denied — please enable it in '
                      'Settings, then come back to this screen.'
                  : 'Bingwa Nexus needs the Phone permission to detect your SIM '
                      'cards and choose which SIM dials USSDs and sends replies.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: permanent ? () => openAppSettings() : _retry,
                icon: Icon(permanent ? Icons.settings : Icons.lock_open),
                label: Text(permanent ? 'Open Settings' : 'Grant Permission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shown when permission IS granted but the platform reports no active SIM.
  Widget _noSimCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No active SIM detected. Insert a SIM card to choose your dialing '
              'and reply SIMs, then tap refresh. (An eSIM-only or unregistered '
              'SIM may not be reported by the system.)',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        // White surface via Material (not a colored BoxDecoration) so the enclosed
        // ListTiles paint background + ink on a Material ancestor — a colored
        // DecoratedBox between a ListTile and its Material trips
        // ListTile._debugCheckBackgroundIsHidden. Outer Container keeps the shadow only.
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.grey.withValues(alpha: 0.15), blurRadius: 6),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  // Shared SIM row: a SIM-card icon, the "SIM N" primary label, the carrier (or
  // not-detected) subtitle, and a trailing Switch. Hybrid renders EVERY SIM role
  // with a Material Switch labelled "SIM 1"/"SIM 2" — so all three sections use this
  // row (receive = independent; dial/reply = exclusive, via the wrappers below).
  // Disabled (onChanged null) when the slot has no active SIM.
  Widget _simRow({
    required int slot,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final active = _slotActive(slot);
    return ListTile(
      leading: Icon(Icons.sim_card_outlined, color: active ? _green : Colors.grey),
      title: Text(_slotName(slot),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        _carrierSubtitle(slot),
        style: TextStyle(fontSize: 12, color: active ? Colors.grey[600] : Colors.grey),
      ),
      trailing: Switch(value: value, activeThumbColor: _green, onChanged: onChanged),
      onTap: (active && onChanged != null) ? () => onChanged(!value) : null,
    );
  }

  // Independent toggle (SIM to receive payments): each SIM on/off on its own.
  // Mirrors Hybrid's validateEnabledSimCards, which reads RECEIVE_PAYMENTS_VIA_SIM_1
  // AND _SIM_2 as a set (either / both / neither).
  Widget _simSwitchRow(int slot, bool value, ValueChanged<bool> onChanged) =>
      _simRow(slot: slot, value: value, onChanged: _slotActive(slot) ? onChanged : null);

  // Exclusive selector rendered as a Switch (dial / auto-reply). Hybrid stores this
  // as the single _VIA_SIM_2 boolean its resolver reads (slot = VIA_SIM_2 ? 2 : 1),
  // so picking a slot just sets that boolean. Tapping the already-on SIM re-selects
  // it (can't switch it off) — exactly one stays selected, like a radio.
  Widget _simExclusiveSwitchRow(int slot, bool selected, VoidCallback onSelected) =>
      _simRow(
        slot: slot,
        value: selected,
        onChanged: _slotActive(slot) ? (_) => onSelected() : null,
      );
}