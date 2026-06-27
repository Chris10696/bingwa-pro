// lib/features/sitelink/presentation/screens/sitelink_screen.dart
// W5.G.4 — the real SiteLink store screen (replaces the W4 "coming soon" placeholder).
// Create/show the store, toggle it active, manage which offers are published, and assign
// each offer to a device (fleet picker). The public page itself is your web deployment.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/sitelink_model.dart';
import '../providers/sitelink_provider.dart';
import 'create_sitelink_screen.dart';
import 'add_sitelink_offer_screen.dart';

class SiteLinkScreen extends ConsumerWidget {
  const SiteLinkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(siteLinkProvider);

    ref.listen(siteLinkProvider.select((s) => s.error), (_, next) {
      if (next != null && next.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      appBar: CustomAppBar(
        title: 'SiteLink',
        showBackButton: true,
        actions: [
          if (state.hasSiteLink)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        CreateSiteLinkScreen(existing: state.siteLink),
                  ));
                } else if (v == 'delete') {
                  _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit store')),
                PopupMenuItem(value: 'delete', child: Text('Delete store')),
              ],
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.hasSiteLink
              ? _StoreView(state: state)
              : const _EmptyState(),
    );
  }

  static void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete store?'),
        content: const Text(
            'Your SiteLink and its published offers will be removed. '
            'Your offers themselves are not deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(siteLinkProvider.notifier).deleteSiteLink();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Empty state (no store yet) ───────────────────────────────────────────────────────
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Create your customer-facing store',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Get a shareable link where customers pick an offer and pay. '
              'Orders come straight to your phone.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const CreateSiteLinkScreen(),
              )),
              icon: const Icon(Icons.add),
              label: const Text('Create SiteLink'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Store view (store exists) ─────────────────────────────────────────────────────────
class _StoreView extends ConsumerWidget {
  final SiteLinkState state;
  const _StoreView({required this.state});

  static const _green = Color(0xFF00C853);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sl = state.siteLink!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _headerCard(context, ref, sl),
        const SizedBox(height: 20),
        _offersHeader(context),
        const SizedBox(height: 8),
        if (state.offers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No offers on your store yet.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...state.offers.map((o) => _offerCard(context, ref, o)),
      ],
    );
  }

  Widget _headerCard(BuildContext context, WidgetRef ref, SiteLink sl) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sl.siteName,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${sl.accountType.label} · ${sl.accountNumber}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(sl.url,
                        style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w500)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: _green),
                    tooltip: 'Copy link',
                    onPressed: () => _copy(context, sl.url),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_browser,
                        size: 20, color: Colors.blue),
                    tooltip: 'Open',
                    onPressed: () => _open(sl.url),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sms_outlined,
                        size: 20, color: _green),
                    tooltip: 'Send via SMS',
                    onPressed: () => _shareSms(sl.url),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(sl.isActive ? Icons.link : Icons.link_off,
                        color: sl.isActive ? _green : Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      sl.isActive ? 'Store is Active' : 'Store is Inactive',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: sl.isActive ? _green : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: sl.isActive,
                  activeColor: _green,
                  onChanged: state.isBusy
                      ? null
                      : (v) =>
                          ref.read(siteLinkProvider.notifier).setActive(v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _offersHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('SiteLink Offers',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AddSiteLinkOfferScreen(),
          )),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Offer'),
          style: TextButton.styleFrom(foregroundColor: _green),
        ),
      ],
    );
  }

  Widget _offerCard(BuildContext context, WidgetRef ref, SiteLinkOffer o) {
    final deviceLabel = _deviceLabel(o.relayDevice);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(Formatters.formatCurrency(o.price.toDouble()),
                          style: const TextStyle(
                              color: _green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Switch(
                  value: o.isActive,
                  activeColor: _green,
                  onChanged: state.isBusy
                      ? null
                      : (v) => ref
                          .read(siteLinkProvider.notifier)
                          .setOfferActive(o.siteLinkOfferId, v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.grey),
                  onPressed: state.isBusy
                      ? null
                      : () => ref
                          .read(siteLinkProvider.notifier)
                          .removeOffer(o.siteLinkOfferId),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: state.isBusy
                  ? null
                  : () => _showDevicePicker(context, ref, o),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.smartphone,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('Dials on: $deviceLabel',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                    const Icon(Icons.arrow_drop_down,
                        size: 18, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _deviceLabel(String? relayDevice) {
    if (relayDevice == null || relayDevice.isEmpty) return 'Any device';
    final match = state.devices
        .where((d) => d.deviceId == relayDevice)
        .toList();
    return match.isNotEmpty ? match.first.label : 'Assigned device';
  }

  void _showDevicePicker(BuildContext context, WidgetRef ref, SiteLinkOffer o) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Which device dials this offer?',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.devices_other),
                title: const Text('Any device'),
                trailing: (o.relayDevice == null || o.relayDevice!.isEmpty)
                    ? const Icon(Icons.check, color: _green)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  ref
                      .read(siteLinkProvider.notifier)
                      .setOfferDevice(o.offerId, null);
                },
              ),
              ...state.devices.map((d) => ListTile(
                    leading: const Icon(Icons.smartphone),
                    title: Text(d.label),
                    trailing: o.relayDevice == d.deviceId
                        ? const Icon(Icons.check, color: _green)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      ref
                          .read(siteLinkProvider.notifier)
                          .setOfferDevice(o.offerId, d.deviceId);
                    },
                  )),
              if (state.devices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No other devices registered yet. Open the app on your '
                    'other phones to add them.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareSms(String url) async {
    final sms = Uri(
      scheme: 'sms',
      queryParameters: {'body': 'Buy airtime & data here: $url'},
    );
    if (await canLaunchUrl(sms)) await launchUrl(sms);
  }
}
