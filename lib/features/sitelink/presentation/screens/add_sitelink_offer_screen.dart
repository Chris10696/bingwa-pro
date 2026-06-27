// lib/features/sitelink/presentation/screens/add_sitelink_offer_screen.dart
// W5.G.4 — publish one of the agent's existing offers to the SiteLink store
// (Hybrid AddSiteLinkOffer). Lists the agent's active offers not already on the store.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../offers/presentation/providers/offer_provider.dart';
import '../providers/sitelink_provider.dart';

class AddSiteLinkOfferScreen extends ConsumerStatefulWidget {
  const AddSiteLinkOfferScreen({super.key});

  @override
  ConsumerState<AddSiteLinkOfferScreen> createState() =>
      _AddSiteLinkOfferScreenState();
}

class _AddSiteLinkOfferScreenState
    extends ConsumerState<AddSiteLinkOfferScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final offers = ref.read(offersNotifierProvider);
      if (offers.offers.isEmpty && !offers.isLoading) {
        ref.read(offersNotifierProvider.notifier).loadOffers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final offersState = ref.watch(offersNotifierProvider);
    final siteLinkState = ref.watch(siteLinkProvider);
    final busy = siteLinkState.isBusy;
    final addedIds =
        siteLinkState.offers.map((o) => o.offerId).toSet();

    // Only the agent's active offers that aren't already on the store.
    final candidates = offersState.offers
        .where((o) => o.isActive && !addedIds.contains(o.id))
        .toList();

    return Scaffold(
      appBar: const CustomAppBar(title: 'Add Offer', showBackButton: true),
      body: offersState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : candidates.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No more offers to add.\nAll your active offers are '
                      'already on the store.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: candidates.length,
                  itemBuilder: (context, i) {
                    final o = candidates[i];
                    return Card(
                      child: ListTile(
                        title: Text(o.name),
                        subtitle:
                            Text(Formatters.formatCurrency(o.price.toDouble())),
                        trailing: busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_circle_outline),
                        onTap: busy
                            ? null
                            : () async {
                                final ok = await ref
                                    .read(siteLinkProvider.notifier)
                                    .addOffer(o.id);
                                if (!context.mounted) return;
                                if (ok) {
                                  Navigator.of(context).pop();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ref.read(siteLinkProvider).error ??
                                            'Could not add offer',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                      ),
                    );
                  },
                ),
    );
  }
}
