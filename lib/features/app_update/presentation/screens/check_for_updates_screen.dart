// lib/features/app_update/presentation/screens/check_for_updates_screen.dart
// W5.H — "Check For Updates" (Hybrid CheckForUpdatesScreen). Shows the installed vs latest
// version and, when an update is available, downloads + installs it via the native updater.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/custom_app_bar.dart';
import '../providers/app_update_provider.dart';

class CheckForUpdatesScreen extends ConsumerWidget {
  const CheckForUpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateProvider);
    final notifier = ref.read(appUpdateProvider.notifier);
    final theme = Theme.of(context);

    ref.listen(appUpdateProvider.select((s) => s.error), (_, next) {
      if (next != null && next.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      appBar: const CustomAppBar(title: 'Check For Updates', showBackButton: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: state.isChecking
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Checking for updates…'),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      state.updateAvailable
                          ? Icons.system_update
                          : Icons.check_circle_outline,
                      size: 64,
                      color: state.updateAvailable
                          ? theme.colorScheme.primary
                          : Colors.green,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.updateAvailable
                          ? 'Update available'
                          : 'You\'re up to date',
                      style: theme.textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Installed: version ${state.currentVersion} '
                      '(${state.currentVersionCode})',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor),
                    ),
                    if (state.updateAvailable) ...[
                      Text(
                        'Latest: version ${state.latest!.latestVersion}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.hintColor),
                      ),
                      if (state.latest!.releaseNotes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(state.latest!.releaseNotes),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: state.isDownloading
                            ? null
                            : () => _install(context, ref),
                        icon: state.isDownloading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download),
                        label: Text(state.isDownloading
                            ? 'Starting download…'
                            : 'Download & Install'),
                      ),
                    ] else ...[
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: notifier.checkForUpdate,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Check again'),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _install(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(appUpdateProvider.notifier);
    final canInstall = await notifier.canInstall();
    if (!context.mounted) return;
    if (!canInstall) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Allow installs'),
          content: const Text(
            'To update, allow Bingwa Nexus to install apps. We\'ll open the '
            'setting — enable it, then come back and tap Download & Install.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (go == true) await notifier.openInstallSettings();
      return;
    }
    await notifier.install();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Downloading update… you\'ll be prompted to install when it\'s ready.'),
      ),
    );
  }
}
