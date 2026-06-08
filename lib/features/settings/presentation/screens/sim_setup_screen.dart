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
// State is read from native on entry: dial/reply via the two "via SIM2" booleans, receive
// via the two receive booleans. (Single-SIM defaults: dial SIM1, reply SIM1, receive SIM1 on.)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/session_bridge_service.dart';

class SimSetupScreen extends ConsumerStatefulWidget {
  const SimSetupScreen({super.key});

  @override
  ConsumerState<SimSetupScreen> createState() => _SimSetupScreenState();
}

class _SimSetupScreenState extends ConsumerState<SimSetupScreen> {
  static const _green = Color(0xFF00C853);

  // Native getters live on the same session channel; the service exposes setters +
  // getSimInfo. For the initial toggle state we read the booleans directly here.
  static const MethodChannel _channel = MethodChannel('bingwa_pro/session');

  bool _loading = true;

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
    _load();
  }

  Future<void> _load() async {
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

  String _label(int slot) => _simLabels[slot] ?? 'SIM $slot';

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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_simLabels.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      'No active SIMs detected. Settings are saved but take effect '
                      'once a SIM is present and phone permissions are granted.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                _section(
                  title: 'SIM to receive payments',
                  children: [
                    _simSwitchRow(1, _receiveSim1,
                        (v) => _onReceiveChanged(1, v)),
                    _simSwitchRow(2, _receiveSim2,
                        (v) => _onReceiveChanged(2, v)),
                  ],
                ),
                const SizedBox(height: 24),
                _section(
                  title: 'Bingwa SIM (To run USSDs)',
                  children: [
                    _simRadioRow(1, !_dialViaSim2, () => _onDialSelected(1)),
                    _simRadioRow(2, _dialViaSim2, () => _onDialSelected(2)),
                  ],
                ),
                const SizedBox(height: 24),
                _section(
                  title: 'Send Auto-Replies Using',
                  children: [
                    _simRadioRow(1, !_replyViaSim2, () => _onReplySelected(1)),
                    _simRadioRow(2, _replyViaSim2, () => _onReplySelected(2)),
                  ],
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
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.grey.withValues(alpha: 0.15), blurRadius: 6),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  // Independent toggle row.
  Widget _simSwitchRow(int slot, bool value, ValueChanged<bool> onChanged) {
    final active = _slotActive(slot);
    return ListTile(
      leading: const Icon(Icons.sim_card_outlined, color: _green),
      title: Text(_label(slot)),
      subtitle: active ? null : Text('SIM $slot — not detected',
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Switch(
        value: value,
        activeColor: _green,
        onChanged: active ? onChanged : null,
      ),
    );
  }

  // Exclusive (radio) row.
  Widget _simRadioRow(int slot, bool selected, VoidCallback onSelected) {
    final active = _slotActive(slot);
    return ListTile(
      leading: const Icon(Icons.sim_card_outlined, color: _green),
      title: Text(_label(slot)),
      subtitle: active ? null : Text('SIM $slot — not detected',
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Radio<bool>(
        value: true,
        groupValue: selected ? true : null,
        activeColor: _green,
        onChanged: active ? (_) => onSelected() : null,
      ),
      onTap: active ? onSelected : null,
    );
  }
}