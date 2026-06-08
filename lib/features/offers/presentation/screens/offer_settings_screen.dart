// lib/features/offers/presentation/screens/offer_settings_screen.dart
// W3.H — "Offer Settings" screen (Hybrid OfferSettingsScreen). Reached via the
// gear icon on the Edit Offer screen (D-W3-10b). Exactly 7 fields, auto-saved on
// every change (no Save button — Hybrid's updateXxx() persists immediately).
// USSD Timeout is shown in seconds, stored as ussdTimeoutMillis (× 1000).
// relayDevice is NOT exposed (W5).
//
// FLAGS:
//  - Stepper bounds (min/max/step) are sensible defaults; Hybrid's exact bounds
//    were not recoverable from the Compose screen. The pipeline honours whatever
//    value is stored, so bounds only constrain UI input.
//  - The Auto Reschedule section's UI (switch + time picker) and the "HH:mm"
//    string format for autoRescheduleRunTime are inferred — the primer's
//    screenshot bullets don't detail this section.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/offer_settings_provider.dart';

class OfferSettingsScreen extends ConsumerWidget {
  final String offerId;
  const OfferSettingsScreen({super.key, required this.offerId});

  static const _green = Color(0xFF00C853);

  // Sensible UI bounds (flagged — not bytecode-confirmed).
  static const _timeoutMin = 5, _timeoutMax = 120, _timeoutStep = 5;
  static const _retriesMin = 0, _retriesMax = 10, _retriesStep = 1;
  static const _intervalMin = 1, _intervalMax = 60, _intervalStep = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offerSettingsProvider(offerId));
    final notifier = ref.read(offerSettingsProvider(offerId).notifier);

    ref.listen<OfferSettingsState>(offerSettingsProvider(offerId), (prev, next) {
      if (next.errorMessage != null &&
          prev?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.red),
        );
        notifier.clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer Settings'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _ussdTimeoutSection(state, notifier),
                const Divider(height: 1),
                _autoRetrySection(state, notifier),
                const Divider(height: 1),
                _autoRetryConnectionSection(state, notifier),
                const Divider(height: 1),
                _autoRescheduleSection(context, state, notifier),
              ],
            ),
    );
  }

  // 1) USSD Timeout — collapsible (chevron), seconds stepper.
  Widget _ussdTimeoutSection(
      OfferSettingsState state, OfferSettingsNotifier notifier) {
    return ExpansionTile(
      leading: const Icon(Icons.timer_outlined, color: _green),
      title: const Text('USSD Timeout',
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${state.ussdTimeoutSeconds}s'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        const _HelpText('Set a higher timeout when in low network coverage areas'),
        const SizedBox(height: 12),
        _Stepper(
          label: 'Timeout (seconds)',
          value: state.ussdTimeoutSeconds,
          min: _timeoutMin,
          max: _timeoutMax,
          step: _timeoutStep,
          onChanged: notifier.updateUssdTimeout,
        ),
      ],
    );
  }

  // 2) Auto Retry — switch (default ON) revealing two nested steppers.
  Widget _autoRetrySection(
      OfferSettingsState state, OfferSettingsNotifier notifier) {
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.refresh, color: _green),
          activeThumbColor: _green,
          title: const Text('Auto Retry',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Retry failed requests automatically'),
          value: state.autoRetry,
          onChanged: notifier.updateAutoRetry,
        ),
        if (state.autoRetry)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                _Stepper(
                  label: 'Retry Interval (minutes)',
                  value: state.retryIntervalMins,
                  min: _intervalMin,
                  max: _intervalMax,
                  step: _intervalStep,
                  onChanged: notifier.updateRetryInterval,
                ),
                const SizedBox(height: 8),
                _Stepper(
                  label: 'Number of Retries',
                  value: state.numberOfRetries,
                  min: _retriesMin,
                  max: _retriesMax,
                  step: _retriesStep,
                  onChanged: notifier.updateNumberOfRetries,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 3) Auto Retry Connection Problems — switch (default ON).
  Widget _autoRetryConnectionSection(
      OfferSettingsState state, OfferSettingsNotifier notifier) {
    return SwitchListTile(
      secondary: const Icon(Icons.wifi_off, color: _green),
      activeThumbColor: _green,
      title: const Text('Auto Retry Connection Problems',
          style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Automatically retry when connection issues occur'),
      value: state.autoRetryConnectionProblems,
      onChanged: notifier.updateAutoRetryConnectionProblems,
    );
  }

  // 4) Auto Reschedule — switch + run-time picker (INFERRED UI; flagged above).
  Widget _autoRescheduleSection(BuildContext context, OfferSettingsState state,
      OfferSettingsNotifier notifier) {
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.schedule, color: _green),
          activeThumbColor: _green,
          title: const Text('Auto Reschedule',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Reschedule failed requests to run later'),
          value: state.autoReschedule,
          onChanged: notifier.updateAutoReschedule,
        ),
        if (state.autoReschedule)
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            title: const Text('Run time'),
            trailing: Text(
              state.autoRescheduleRunTime ?? 'Set time',
              style: const TextStyle(
                  color: _green, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            onTap: () => _pickRunTime(context, state, notifier),
          ),
      ],
    );
  }

  Future<void> _pickRunTime(BuildContext context, OfferSettingsState state,
      OfferSettingsNotifier notifier) async {
    final initial = _parseTime(state.autoRescheduleRunTime) ??
        const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final hh = picked.hour.toString().padLeft(2, '0');
      final mm = picked.minute.toString().padLeft(2, '0');
      await notifier.updateRescheduleTime('$hh:$mm'); // "HH:mm" (inferred format)
    }
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}

class _HelpText extends StatelessWidget {
  final String text;
  const _HelpText(this.text);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
      );
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value, min, max, step;
  final ValueChanged<int> onChanged;
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  static const _green = Color(0xFF00C853);

  @override
  Widget build(BuildContext context) {
    final canDec = value - step >= min;
    final canInc = value + step <= max;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: canDec ? _green : Colors.grey,
              onPressed: canDec ? () => onChanged(value - step) : null,
            ),
            SizedBox(
              width: 36,
              child: Text('$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: canInc ? _green : Colors.grey,
              onPressed: canInc ? () => onChanged(value + step) : null,
            ),
          ],
        ),
      ],
    );
  }
}