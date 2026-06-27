// lib/features/settings/presentation/screens/accessibility_required_screen.dart
//
// W3.I: Pro's equivalent of Hybrid's AccessibilityInfoScreen (Route$AccessibilityInfo).
// Shown when the agent selects Advanced processing mode while our accessibility
// service is not yet enabled. Instructs the agent how to enable it and opens the
// system Accessibility settings via the native bridge
// (SessionBridgeService.openAccessibilitySettings → Settings.ACTION_ACCESSIBILITY_SETTINGS).
//
// Pushed imperatively with Navigator.push from the Settings screen, so it needs no
// go_router registration. Behaviourally identical to Hybrid: a screen opens with
// the steps + an "Open Accessibility Settings" button. Step 4 names the Pro
// service ("Bingwa Nexus service") — IMPORTANT: this must match the label Android
// shows for UssdAccessibilityService, which comes from
// @string/accessibility_service_description in the on-device build. If that
// description differs, update this copy (or the string) so they agree.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/session_bridge_service.dart';

class AccessibilityRequiredScreen extends ConsumerWidget {
  const AccessibilityRequiredScreen({super.key});

  static const Color _green = Color(0xFF00C853);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Service Required'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Advanced Mode requires the Accessibility service to be '
                    'activated.\nPlease follow the steps below to enable it:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  _step(1, "Open your device's Settings app."),
                  _step(2, "Tap on 'Accessibility'."),
                  _step(3, "Tap on 'Installed apps (or services)'."),
                  _step(4, 'Find and tap on the Bingwa Nexus service.'),
                  _step(5, 'Toggle the switch to enable the service.'),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: () => ref
                        .read(sessionBridgeServiceProvider)
                        .openAccessibilitySettings(),
                    child: const Text(
                      'Open Accessibility Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(int n, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$n.',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 15, height: 1.3)),
          ),
        ],
      ),
    );
  }
}