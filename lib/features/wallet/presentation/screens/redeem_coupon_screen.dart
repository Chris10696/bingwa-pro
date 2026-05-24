// lib/features/wallet/presentation/screens/redeem_coupon_screen.dart
// W2.4A: redeem a promo code. Calls walletNotifier.redeemCoupon(code), which
// inspects statusCode (dio validateStatus<500 → 400/404 resolve, not throw).
// On success the provider refreshes balance; this screen shows the result
// ({name, durationHours}) and lets the agent return to the wallet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../providers/wallet_provider.dart';

class RedeemCouponScreen extends ConsumerStatefulWidget {
  const RedeemCouponScreen({super.key});
  @override
  ConsumerState<RedeemCouponScreen> createState() =>
      _RedeemCouponScreenState();
}

class _RedeemCouponScreenState extends ConsumerState<RedeemCouponScreen> {
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Clear any stale coupon result/error from a previous visit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletNotifierProvider.notifier).clearCouponState();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _durationLabel(double hours) {
    if (hours <= 0) return '';
    if (hours >= 24) {
      final days = (hours / 24).floor();
      final rem = (hours % 24).round();
      return rem > 0 ? '$days day(s) $rem hr(s)' : '$days day(s)';
    }
    return '${hours.round()} hour(s)';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletNotifierProvider);
    final notifier = ref.read(walletNotifierProvider.notifier);

    // Surface a success snackbar when a coupon redeems.
    ref.listen<WalletState>(walletNotifierProvider, (prev, next) {
      if (prev?.couponResult == null && next.couponResult != null) {
        final r = next.couponResult!;
        final dur = _durationLabel(r.durationHours);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              dur.isEmpty
                  ? 'Redeemed: ${r.name}'
                  : 'Redeemed: ${r.name} ($dur)',
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Redeem Promo Code',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your promo code',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Redeeming a valid code activates a subscription plan instantly.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Promo Code',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.confirmation_number_outlined),
                errorText: state.couponError,
              ),
              onChanged: (_) {
                if (state.couponError != null) notifier.clearCouponState();
              },
            ),
            const SizedBox(height: 16),
            if (state.couponResult != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Activated ${state.couponResult!.name}'
                        '${_durationLabel(state.couponResult!.durationHours).isEmpty ? '' : ' — ${_durationLabel(state.couponResult!.durationHours)}'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: state.isRedeemingCoupon
                    ? null
                    : () {
                        final code = _codeController.text.trim();
                        if (code.isEmpty) return;
                        notifier.redeemCoupon(code);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: state.isRedeemingCoupon
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Apply',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}