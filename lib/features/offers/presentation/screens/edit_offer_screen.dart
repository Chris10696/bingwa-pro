// lib/features/offers/presentation/screens/edit_offer_screen.dart
// W3.H (D-W3-10b) — full Edit/Add Offer screen (Hybrid AddOrEditOfferScreen),
// replacing Pro's W2 edit *dialog*. Reached by tapping an offer card (edit) or
// the FAB type-picker (add). In EDIT mode the app bar carries a gear icon
// (top-right) → Offer Settings (the 7 retry/timeout fields), plus a Delete Offer
// button and an "Update" action. In ADD mode there is no gear/delete and the
// action is "Create" (retry settings only apply to an existing offer).
//
// Uses offersNotifierProvider so the My Offers list stays in sync — identical
// create/update/delete calls to the dialog this replaces.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/offer_model.dart';
import '../providers/offer_provider.dart';
import 'offer_settings_screen.dart';

class EditOfferScreen extends ConsumerStatefulWidget {
  final Offer? existing;
  final OfferType? presetType;
  const EditOfferScreen({super.key, this.existing, this.presetType});

  @override
  ConsumerState<EditOfferScreen> createState() => _EditOfferScreenState();
}

class _EditOfferScreenState extends ConsumerState<EditOfferScreen> {
  static const _green = Color(0xFF00C853);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ussdCtrl;
  late final TextEditingController _priceCtrl;
  late OfferType _type;
  late bool _isActive;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _ussdCtrl = TextEditingController(text: e?.ussdCode ?? '');
    _priceCtrl = TextEditingController(text: e != null ? '${e.price}' : '');
    _type = e?.type ?? widget.presetType ?? OfferType.data;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ussdCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Surface mutation errors from the offers notifier as a snackbar.
    ref.listen<OffersState>(offersNotifierProvider, (prev, next) {
      if (next.errorMessage != null &&
          prev?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: Colors.red),
        );
        ref.read(offersNotifierProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Offer' : 'New Offer'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Offer Settings',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      OfferSettingsScreen(offerId: widget.existing!.id),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ussdCtrl,
                decoration: const InputDecoration(
                  labelText: 'USSD Code',
                  hintText: '*180*5*2*BH*1*1#',
                  border: OutlineInputBorder(),
                ),
                validator: _validateUssd,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceCtrl,
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
              const SizedBox(height: 16),
              DropdownButtonFormField<OfferType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: OfferType.data, child: Text('Data')),
                  DropdownMenuItem(value: OfferType.voice, child: Text('Minutes')),
                  DropdownMenuItem(value: OfferType.sms, child: Text('SMS')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _isActive,
                activeThumbColor: _green,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isEdit ? 'Update' : 'Create'),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Offer'),
                  onPressed: _saving ? null : _confirmDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final ussd = _ussdCtrl.text.trim();
    final price = int.parse(_priceCtrl.text.trim());
    final notifier = ref.read(offersNotifierProvider.notifier);
    setState(() => _saving = true);
    if (_isEdit) {
      await notifier.updateOffer(
        widget.existing!.id,
        name: name,
        ussdCode: ussd,
        price: price,
        type: _type,
        isActive: _isActive,
      );
    } else {
      await notifier.createOffer(
        name: name,
        ussdCode: ussd,
        price: price,
        type: _type,
        isActive: _isActive,
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Offer'),
        content: Text('Delete "${widget.existing!.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref
                  .read(offersNotifierProvider.notifier)
                  .deleteOffer(widget.existing!.id);
              if (!mounted) return;
              Navigator.pop(context); // leave the edit screen after delete
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Mirrors backend @Matches(/^\*[\d*]+(BH|BN)[\d*]*#$/): starts *, ends #, has the
  // phone placeholder. Accepts BOTH the legacy "BH" and the rebranded "BN" token — keep
  // the backend validator on the SAME dual-token regex so the two stay in lockstep.
  String? _validateUssd(String? v) {
    final code = v?.trim() ?? '';
    if (code.isEmpty) return 'USSD code is required';
    if (!code.startsWith('*') || !code.endsWith('#')) {
      return 'Must start with * and end with #';
    }
    if (!code.contains('BN') && !code.contains('BH')) {
      return 'Must contain the BN placeholder (customer phone)';
    }
    return null;
  }
}