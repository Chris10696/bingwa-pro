// lib/features/hybrid_connect/presentation/screens/hybrid_connect_screen.dart
// W5.F.3 — Nexus Connect / Portal screen (port of Hybrid's HybridConnectScreen, rebranded).
//
// The agent generates a Connect ID, copies/shares it with the web Portal, and flips the
// "Online" switch to link this phone to the Portal over the socket. The status dot shows
// the live Connected/Disconnected state. Rebrand precaution: "Nexus", never "Hybrid".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/hybrid_connect_provider.dart';

class HybridConnectScreen extends ConsumerWidget {
  const HybridConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hybridConnectProvider);
    final notifier = ref.read(hybridConnectProvider.notifier);
    final theme = Theme.of(context);

    ref.listen(hybridConnectProvider.select((s) => s.error), (_, next) {
      if (next != null && next.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next), backgroundColor: Colors.red),
        );
      }
    });

    final connected = state.isConnected;

    return Scaffold(
      appBar: AppBar(title: const Text('Nexus Connect')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Live status ────────────────────────────────────────────────
          Row(
            children: [
              _Dot(color: connected ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Text(
                connected ? 'Connected' : 'Disconnected',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: connected ? Colors.green : theme.hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Help text (rebranded from Hybrid) ──────────────────────────
          Text(
            'Connect multiple devices with Nexus Connect. For best performance, '
            'make sure this device is connected to WiFi or a WiFi hotspot.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 20),

          // ── Connect ID card ────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Connect ID', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  if (state.hasConnectId)
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            state.connectId!,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy',
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: state.connectId!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Connect ID copied')),
                            );
                          },
                        ),
                      ],
                    )
                  else
                    Text(
                      'No Connect ID yet. Generate one to link the Portal.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.hintColor),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: state.isBusy ? null : notifier.generate,
                      icon: const Icon(Icons.refresh),
                      label: Text(state.hasConnectId
                          ? 'Regenerate Connect ID'
                          : 'Generate Connect ID'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Online toggle (starts/stops the socket FGS) ────────────────
          Card(
            child: SwitchListTile(
              title: const Text('Online'),
              subtitle: const Text(
                  'Link this phone to the Portal for remote monitoring'),
              value: state.isOnline,
              onChanged: state.isBusy ? null : (v) => notifier.setOnline(v),
            ),
          ),

          if (state.isBusy) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
