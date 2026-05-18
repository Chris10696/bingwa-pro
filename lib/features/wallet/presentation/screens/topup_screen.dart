// lib/features/wallet/presentation/screens/topup_screen.dart
// W1: rewritten for Q8a/Q8b — package selection + STK push + fallback confirm.
//   Flow:
//     1. Load packages via wallet provider's state.packages.
//     2. User taps a package → state.selectedPackageId set.
//     3. User taps Subscribe → notifier.purchaseSubscription(packageId).
//        Backend stub records PENDING purchase (W2 wires real STK).
//     4. Show spinner + "Check your phone for the M-Pesa PIN prompt".
//     5. After 15s, reveal "I have paid" fallback button (Q8b path ii).
//     6. Tap "I have paid" → notifier.confirmPayment(purchaseId).
//     7. Success/failure dialogs.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../shared/models/subscription_package_model.dart';
import '../../../../shared/models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  // Tracks whether the 15-second timer has elapsed, gating the
  // "I have paid" fallback button (Q8b path ii).
  bool _showManualConfirm = false;
  Timer? _manualConfirmTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletNotifierProvider.notifier).loadWalletData();
    });
  }

  @override
  void dispose() {
    _manualConfirmTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletNotifierProvider);

    // Auto-show success/failure dialog when pendingPurchase status flips.
    // Note: in W1 the backend stub never flips status server-side, so this
    // is exercised only when the manual confirm button is tapped.
    ref.listen<WalletState>(walletNotifierProvider, (prev, next) {
      final prevStatus = prev?.pendingPurchase?.status;
      final nextStatus = next.pendingPurchase?.status;
      if (prevStatus == SubscriptionPurchaseStatus.pending &&
          nextStatus != SubscriptionPurchaseStatus.pending &&
          nextStatus != null) {
        if (nextStatus == SubscriptionPurchaseStatus.completed) {
          _showSuccessDialog();
        } else if (nextStatus == SubscriptionPurchaseStatus.failed) {
          _showFailureDialog();
        }
      }
    });

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Subscribe',
        showBackButton: true,
      ),
      body: state.isLoading && state.packages.isEmpty
          ? const LoadingIndicator(message: 'Loading plans...')
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a Plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'You will receive an M-Pesa PIN prompt on your registered phone.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildPackagesList(state)),
                  const SizedBox(height: 16),
                  _buildSubscribeButton(state),
                  if (state.isPurchasingSubscription ||
                      state.pendingPurchase?.status ==
                          SubscriptionPurchaseStatus.pending)
                    _buildStkWaitPanel(state),
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildPackagesList(WalletState state) {
    if (state.packages.isEmpty) {
      return const Center(
        child: Text(
          'No subscription plans available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: state.packages.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final pkg = state.packages[i];
        final isSelected = state.selectedPackageId == pkg.id;
        return _buildPackageCard(pkg, isSelected);
      },
    );
  }

  Widget _buildPackageCard(SubscriptionPackage pkg, bool isSelected) {
    return InkWell(
      onTap: () =>
          ref.read(walletNotifierProvider.notifier).selectPackage(pkg.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00C853).withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00C853)
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                pkg.type == SubscriptionType.unlimited
                    ? Icons.all_inclusive
                    : Icons.confirmation_number,
                color: const Color(0xFF00C853),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pkg.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (pkg.description != null && pkg.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        pkg.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'KES ${pkg.price}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF00C853),
                  ),
                ),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.check_circle,
                      color: Color(0xFF00C853),
                      size: 18,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribeButton(WalletState state) {
    final hasSelection = state.selectedPackageId != null;
    final disabled =
        !hasSelection || state.isPurchasingSubscription || state.isConfirmingPayment;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: disabled ? null : () => _initiateSubscribe(state),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C853),
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: state.isPurchasingSubscription
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'SUBSCRIBE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  /// Q8b path (ii): spinner + waiting message; after 15s, "I have paid" appears.
  Widget _buildStkWaitPanel(WalletState state) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Check your phone for the M-Pesa PIN prompt. '
                  'Enter your PIN to confirm the payment.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          if (_showManualConfirm && state.pendingPurchase != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: state.isConfirmingPayment
                    ? null
                    : () => _onManualConfirm(state),
                icon: state.isConfirmingPayment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, color: Colors.orange),
                label: const Text(
                  'I have paid',
                  style: TextStyle(color: Colors.orange),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _initiateSubscribe(WalletState state) async {
    final packageId = state.selectedPackageId;
    if (packageId == null) return;

    // Reset the manual-confirm timer state.
    _manualConfirmTimer?.cancel();
    setState(() => _showManualConfirm = false);

    await ref
        .read(walletNotifierProvider.notifier)
        .purchaseSubscription(packageId: packageId);

    if (!mounted) return;

    // Start the 15-second fallback timer.
    _manualConfirmTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() => _showManualConfirm = true);
      }
    });
  }

  Future<void> _onManualConfirm(WalletState state) async {
    final purchase = state.pendingPurchase;
    if (purchase == null) return;
    await ref
        .read(walletNotifierProvider.notifier)
        .confirmPayment(purchase.id);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Icon(
          Icons.check_circle,
          size: 60,
          color: Colors.green,
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Subscription Active!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Your plan is now active. You can return to the wallet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (mounted) {
                  context.pop(); // Close top-up screen
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
              ),
              child: const Text('View Wallet'),
            ),
          ),
        ],
      ),
    );
  }

  void _showFailureDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Icon(Icons.error, size: 60, color: Colors.red),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Payment Failed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Your payment was not successful. Please try again.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) context.pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            child: const Text('Back to Wallet'),
          ),
        ],
      ),
    );
  }
}