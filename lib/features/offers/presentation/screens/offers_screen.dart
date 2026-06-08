// lib/features/offers/presentation/screens/offers_screen.dart
// W2.4B: Hybrid "My Offers" manager.
//   - Filter chips: All / Data / Minutes(VOICE) / SMS
//   - Rows: globe icon + green name + grey USSD code + price + active toggle
//     + delete affordance; tap row = Edit Offer screen (prefilled)
//   - FAB → type-picker → Edit Offer screen (add mode)
// W3.H (D-W3-10b): the W2 edit *dialog* is replaced by the full EditOfferScreen
//   (Name/USSD/Price/Activate/Delete/Update + gear → Offer Settings). Tapping a
//   row pushes it in edit mode; the FAB type-picker pushes it in add mode. The
//   USSD validation now lives on that screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../shared/models/offer_model.dart';
import '../providers/offer_provider.dart';
import 'edit_offer_screen.dart';
class OffersScreen extends ConsumerStatefulWidget {
  const OffersScreen({super.key});
  @override
  ConsumerState<OffersScreen> createState() => _OffersScreenState();
}
class _OffersScreenState extends ConsumerState<OffersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(offersNotifierProvider.notifier).loadOffers();
    });
  }
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(offersNotifierProvider);
    final notifier = ref.read(offersNotifierProvider.notifier);
    // Surface mutation errors as a snackbar.
    ref.listen<OffersState>(offersNotifierProvider, (prev, next) {
      if (next.errorMessage != null &&
          prev?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        notifier.clearError();
      }
    });
    return Scaffold(
      appBar: const CustomAppBar(title: 'My Offers', showBackButton: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTypePicker(notifier),
        backgroundColor: const Color(0xFF00C853),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _buildFilterChips(state, notifier),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  // ── Filter chips ────────────────────────────────────────────────────────────
  Widget _buildFilterChips(OffersState state, OffersNotifier notifier) {
    // null = All; VOICE displays as "Minutes".
    final chips = <(String, OfferType?)>[
      ('All', null),
      ('Data', OfferType.data),
      ('Minutes', OfferType.voice),
      ('SMS', OfferType.sms),
    ];
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final (label, type) in chips)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(label),
                selected: state.filter == type,
                onSelected: (_) => notifier.setFilter(type),
                selectedColor: const Color(0xFF00C853),
                labelStyle: TextStyle(
                  color: state.filter == type ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: Colors.grey.shade200,
              ),
            ),
        ],
      ),
    );
  }
  // ── Body ────────────────────────────────────────────────────────────────────
  Widget _buildBody(OffersState state, OffersNotifier notifier) {
    if (state.isLoading && state.offers.isEmpty) {
      return const LoadingIndicator(message: 'Loading offers...');
    }
    if (state.offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_offer, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No offers yet',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Tap + to create your first offer',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => notifier.loadOffers(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.offers.length,
        itemBuilder: (context, i) => _buildOfferRow(state.offers[i], notifier),
      ),
    );
  }

  Widget _buildOfferRow(Offer offer, OffersNotifier notifier) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _openEditor(existing: offer),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.public, color: Color(0xFF00C853)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.name,
                      style: const TextStyle(
                        color: Color(0xFF00C853),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offer.ussdCode,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'KES ${offer.price}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Switch(
                value: offer.isActive,
                activeThumbColor: const Color(0xFF00C853),
                onChanged: (v) => notifier.toggleActive(offer.id, v),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(offer, notifier),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ── Type picker (FAB) ───────────────────────────────────────────────────────
  void _showTypePicker(OffersNotifier notifier) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        Widget tile(OfferType type, IconData icon) => ListTile(
              leading: Icon(icon, color: const Color(0xFF00C853)),
              title: Text(type.displayLabel),
              onTap: () {
                Navigator.pop(sheetCtx);
                _openEditor(presetType: type);
              },
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('New Offer Category',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              tile(OfferType.data, Icons.wifi),
              tile(OfferType.voice, Icons.call), // displays "Minutes"
              tile(OfferType.sms, Icons.message),
            ],
          ),
        );
      },
    );
  }

  // ── Navigate to the full Edit/Add Offer screen (W3.H, replaces the dialog) ────
  void _openEditor({Offer? existing, OfferType? presetType}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditOfferScreen(existing: existing, presetType: presetType),
      ),
    );
  }

  void _confirmDelete(Offer offer, OffersNotifier notifier) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Offer'),
        content: Text('Delete "${offer.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogCtx);
              notifier.deleteOffer(offer.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}