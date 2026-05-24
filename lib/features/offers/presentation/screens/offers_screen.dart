// lib/features/offers/presentation/screens/offers_screen.dart
// W2.4B: Hybrid "My Offers" manager.
//   - Filter chips: All / Data / Minutes(VOICE) / SMS
//   - Rows: globe icon + green name + grey USSD code + price + active toggle
//     + delete affordance; tap row = edit dialog (prefilled)
//   - FAB → type-picker → create dialog (shared with edit)
//   - USSD field: hint + light validation matching backend regex
//     (^\*[\d*]+BH[\d*]*#$ shape: starts *, ends #, contains BH)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../shared/models/offer_model.dart';
import '../providers/offer_provider.dart';

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
        onTap: () => _showOfferDialog(notifier, existing: offer),
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
                _showOfferDialog(notifier, presetType: type);
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

  // ── Create/Edit dialog (shared) ─────────────────────────────────────────────
  void _showOfferDialog(
    OffersNotifier notifier, {
    Offer? existing,
    OfferType? presetType,
  }) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final ussdCtrl = TextEditingController(text: existing?.ussdCode ?? '');
    final priceCtrl =
        TextEditingController(text: existing != null ? '${existing.price}' : '');
    OfferType type = existing?.type ?? presetType ?? OfferType.data;
    bool isActive = existing?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Offer' : 'New Offer'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ussdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'USSD Code',
                          hintText: '*180*5*2*BH*1*1#',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateUssd,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price (KES)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 1) return 'Enter a valid price';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<OfferType>(
                        initialValue: type,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: OfferType.data, child: Text('Data')),
                          DropdownMenuItem(
                              value: OfferType.voice, child: Text('Minutes')),
                          DropdownMenuItem(
                              value: OfferType.sms, child: Text('SMS')),
                        ],
                        onChanged: (v) {
                          if (v != null) setLocal(() => type = v);
                        },
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        activeThumbColor: const Color(0xFF00C853),
                        onChanged: (v) => setLocal(() => isActive = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final name = nameCtrl.text.trim();
                    final ussd = ussdCtrl.text.trim();
                    final price = int.parse(priceCtrl.text.trim());
                    Navigator.pop(dialogCtx);
                    if (isEdit) {
                      await notifier.updateOffer(
                        existing.id,
                        name: name,
                        ussdCode: ussd,
                        price: price,
                        type: type,
                        isActive: isActive,
                      );
                    } else {
                      await notifier.createOffer(
                        name: name,
                        ussdCode: ussd,
                        price: price,
                        type: type,
                        isActive: isActive,
                      );
                    }
                  },
                  child: Text(isEdit ? 'Save' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Mirrors backend @Matches(/^\*[\d*]+BH[\d*]*#$/): starts *, ends #, has BH.
  String? _validateUssd(String? v) {
    final code = v?.trim() ?? '';
    if (code.isEmpty) return 'USSD code is required';
    if (!code.startsWith('*') || !code.endsWith('#')) {
      return 'Must start with * and end with #';
    }
    if (!code.contains('BH')) {
      return 'Must contain the BH placeholder (customer phone)';
    }
    return null;
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