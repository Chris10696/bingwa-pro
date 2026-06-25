// lib/features/quick_dial/presentation/screens/quick_dial_screen.dart
// W2.4C → W3.L: Hybrid "Quick Dial" — customer phone field + offer chip grid
// (3-col) + green dial button. Backend-first via quickDialNotifier.dial();
// the dial now runs through the REAL pipeline (W3.L) and the result is shown
// in a UssdResponseDialog (Hybrid parity) instead of a fire-and-forget snackbar.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../shared/models/offer_model.dart';
import '../../../../shared/models/customer_model.dart';
import '../../../../shared/repositories/customer_repository.dart';
import '../../../offers/presentation/providers/offer_provider.dart';
import '../providers/quick_dial_provider.dart';
class QuickDialScreen extends ConsumerStatefulWidget {
  const QuickDialScreen({super.key});
  @override
  ConsumerState<QuickDialScreen> createState() => _QuickDialScreenState();
}
class _QuickDialScreenState extends ConsumerState<QuickDialScreen> {
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _resultDialogOpen = false;
  // W4-3c: saved-customer autocomplete suggestions for the phone field.
  List<Customer> _suggestions = [];
  Timer? _searchDebounce;
  String _lastQuery = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load the agent's offers (active ones are the dial targets).
      ref.read(offersNotifierProvider.notifier).loadOffers();
    });
  }
  @override
  void dispose() {
    _searchDebounce?.cancel();
    _phoneFocus.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // W4-3c — debounced saved-customer lookup. The phone field is digit-only, so we search by
  // the typed digits and suggest matching saved customers (name + phone). Tapping one fills
  // the field. "Latest query wins" guards against out-of-order responses.
  void _onPhoneChanged(String value, QuickDialNotifier notifier) {
    notifier.setCustomerPhone(value);
    _searchDebounce?.cancel();
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 3) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
      return;
    }
    _searchDebounce =
        Timer(const Duration(milliseconds: 300), () => _searchCustomers(digits));
  }

  Future<void> _searchCustomers(String query) async {
    _lastQuery = query;
    try {
      final results =
          await ref.read(customerRepositoryProvider).searchCustomers(query);
      if (!mounted || _lastQuery != query) return;
      setState(() => _suggestions = results.take(5).toList());
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    }
  }

  void _pickCustomer(Customer c, QuickDialNotifier notifier) {
    _phoneController.text = c.phone;
    notifier.setCustomerPhone(c.phone);
    setState(() => _suggestions = []);
    _phoneFocus.unfocus();
  }
  @override
  Widget build(BuildContext context) {
    final offersState = ref.watch(offersNotifierProvider);
    final dialState = ref.watch(quickDialNotifierProvider);
    final dialNotifier = ref.read(quickDialNotifierProvider.notifier);
    // React to state transitions.
    ref.listen<QuickDialState>(quickDialNotifierProvider, (prev, next) {
      // W3.L: terminal pipeline result → UssdResponseDialog (Hybrid parity).
      if (next.showResultDialog && !_resultDialogOpen) {
        _resultDialogOpen = true;
        _showUssdResponseDialog(
          success: next.dialedSuccess,
          response: next.ussdResponse ?? '',
          onClose: () {
            _resultDialogOpen = false;
            dialNotifier.dismissResultDialog();
            if (next.dialedSuccess) _phoneController.clear();
          },
        );
        return;
      }
      // Errors that are NOT a terminal pipeline result (validation, 402, enqueue
      // failure) — surface inline as before.
      if (prev?.phase != next.phase &&
          next.phase == QuickDialPhase.error &&
          !next.showResultDialog &&
          next.errorMessage != null) {
        if (next.needsSubscription) {
          _showSubscribePrompt(next.errorMessage!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Text(next.errorMessage!),
            ),
          );
        }
        dialNotifier.reset();
      }
    });

    // Active offers only — inactive offers can't be dialed (Hybrid parity).
    final dialableOffers =
        offersState.offers.where((o) => o.isActive).toList();
    return Scaffold(
      appBar: const CustomAppBar(title: 'Quick Dial', showBackButton: true),
      body: Column(
        children: [
          _buildPhoneField(dialNotifier),
          const Divider(height: 1),
          Expanded(
            child: offersState.isLoading && offersState.offers.isEmpty
                ? const LoadingIndicator(message: 'Loading offers...')
                : dialableOffers.isEmpty
                    ? _buildEmpty()
                    : _buildOfferGrid(dialableOffers, dialState, dialNotifier),
          ),
          _buildDialButton(dialState, dialNotifier),
        ],
      ),
    );
  }
  Widget _buildPhoneField(QuickDialNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phoneController,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
            ],
            onChanged: (v) => _onPhoneChanged(v, notifier),
            decoration: const InputDecoration(
              labelText: 'Customer Phone',
              hintText: '07XX XXX XXX',
              prefixIcon: Icon(Icons.person_outline, color: Color(0xFF00C853)),
              border: OutlineInputBorder(),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: _suggestions
                    .map((c) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.person,
                              color: Color(0xFF00C853), size: 20),
                          title: Text(c.name.isEmpty ? c.phone : c.name),
                          subtitle: c.name.isEmpty ? null : Text(c.phone),
                          onTap: () => _pickCustomer(c, notifier),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.speed, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No active offers',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Create or activate an offer first — only active offers '
              'can be dialed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferGrid(
    List<Offer> offers,
    QuickDialState dialState,
    QuickDialNotifier notifier,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: offers.length,
      itemBuilder: (context, i) {
        final offer = offers[i];
        final selected = dialState.selectedOffer?.id == offer.id;
        return InkWell(
          onTap: () => notifier.selectOffer(offer),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF00C853).withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? const Color(0xFF00C853)
                    : Colors.grey.shade300,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_iconFor(offer.type),
                    color: const Color(0xFF00C853), size: 24),
                const SizedBox(height: 6),
                Text(
                  offer.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'KES ${offer.price}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF00C853),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(OfferType type) {
    switch (type) {
      case OfferType.data:
        return Icons.wifi;
      case OfferType.voice:
        return Icons.call;
      case OfferType.sms:
        return Icons.message;
      case OfferType.none:
        return Icons.sim_card;
    }
  }
  Widget _buildDialButton(QuickDialState state, QuickDialNotifier notifier) {
    final canDial = state.selectedOffer != null && !state.isBusy;
    final label = switch (state.phase) {
      QuickDialPhase.recording => 'Recording...',
      QuickDialPhase.dialing => 'Dialing...',
      _ => 'Dial',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: canDial ? () => notifier.dial() : null,
            icon: state.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.phone, color: Colors.white),
            label: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// W3.L — Hybrid's UssdResponseDialog: shows the live pipeline result
  /// (success/failure + the captured USSD response text) the agent watches.
  void _showUssdResponseDialog({
    required bool success,
    required String response,
    required VoidCallback onClose,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? const Color(0xFF00C853) : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(success ? 'Success' : 'Failed'),
          ],
        ),
        content: Text(
          response.isEmpty
              ? (success ? 'Request successful' : 'Request failed')
              : response,
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              onClose();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSubscribePrompt(String message) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Subscription Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.push('/wallet');
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }
}