// lib/features/sitelink/presentation/screens/create_sitelink_screen.dart
// W5.G.4 — create / edit the agent's SiteLink store (Hybrid CreateSiteLink/EditSiteLink).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/custom_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/models/sitelink_model.dart';
import '../providers/sitelink_provider.dart';

class CreateSiteLinkScreen extends ConsumerStatefulWidget {
  /// Non-null = edit mode.
  final SiteLink? existing;
  const CreateSiteLinkScreen({super.key, this.existing});

  @override
  ConsumerState<CreateSiteLinkScreen> createState() =>
      _CreateSiteLinkScreenState();
}

class _CreateSiteLinkScreenState extends ConsumerState<CreateSiteLinkScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _siteName;
  late final TextEditingController _username;
  late final TextEditingController _accountNumber;
  late SiteLinkAccountType _accountType;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final agent = ref.read(authNotifierProvider).agent;
    final defaultName = (agent?.businessName?.isNotEmpty == true)
        ? agent!.businessName!
        : (agent?.fullName ?? '');
    _siteName = TextEditingController(text: e?.siteName ?? defaultName);
    _username = TextEditingController(
        text: e?.username ?? _slugify(defaultName));
    _accountNumber = TextEditingController(text: e?.accountNumber ?? '');
    _accountType = e?.accountType ?? SiteLinkAccountType.till;
  }

  @override
  void dispose() {
    _siteName.dispose();
    _username.dispose();
    _accountNumber.dispose();
    super.dispose();
  }

  String _slugify(String name) => name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(siteLinkProvider.notifier);
    final ok = _isEdit
        ? await notifier.updateSiteLink({
            'siteName': _siteName.text.trim(),
            'username': _username.text.trim(),
            'accountType': _accountType.wire,
            'accountNumber': _accountNumber.text.trim(),
          })
        : await notifier.createSiteLink(
            siteName: _siteName.text.trim(),
            username: _username.text.trim(),
            accountType: _accountType,
            accountNumber: _accountNumber.text.trim(),
          );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      final err = ref.read(siteLinkProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Could not save your SiteLink'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(siteLinkProvider.select((s) => s.isBusy));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: _isEdit ? 'Edit SiteLink' : 'Create SiteLink',
        showBackButton: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _siteName,
              decoration: const InputDecoration(
                labelText: 'Store name',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Enter a store name'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'Username',
                helperText: 'Letters, numbers and underscores only',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.length < 3) return 'At least 3 characters';
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(s)) {
                  return 'Only letters, numbers and underscores';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Your store URL: https://bingwanexus.com/'
              '${_username.text.trim()}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text('Where payments go', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<SiteLinkAccountType>(
              segments: const [
                ButtonSegment(
                    value: SiteLinkAccountType.till, label: Text('Till')),
                ButtonSegment(
                    value: SiteLinkAccountType.mpesa, label: Text('M-Pesa')),
              ],
              selected: {_accountType},
              onSelectionChanged: (s) =>
                  setState(() => _accountType = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNumber,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _accountType == SiteLinkAccountType.till
                    ? 'Till number'
                    : 'M-Pesa number',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().length < 5)
                  ? 'Enter the account number'
                  : null,
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Save changes' : 'Create store'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
