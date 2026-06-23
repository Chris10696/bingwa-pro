// lib/features/wallet/presentation/screens/wallet_screen.dart
// W2.4A: Hybrid Subscription-Plans redesign + topup merge.
//   - Balance header line (Unlimited: Xd XXh XXmin / Limited: X Tokens)
//   - Selectable plan cards + inline Subscribe (no separate topup screen)
//   - Provider-driven STK polling (watches pollStatus); on timeout offers
//     both "Try Again" and "I have paid" (confirmPayment fallback)
//   - "Have a promo code? Redeem here" link → /redeem-coupon
//   - Compact purchase history retained below
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../shared/models/wallet_model.dart';
import '../../../../shared/models/subscription_package_model.dart';
import '../../../../shared/models/subscription_plan_model.dart';
import '../providers/wallet_provider.dart';
import '../widgets/pay_with_airtime_sheet.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});
  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletNotifierProvider.notifier).loadWalletData();
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(walletNotifierProvider.notifier).loadMorePurchases();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletNotifierProvider);
    final notifier = ref.read(walletNotifierProvider.notifier);

    // React to poll-status transitions for the success dialog.
    ref.listen<WalletState>(walletNotifierProvider, (prev, next) {
      if (prev?.pollStatus != StkPollStatus.success &&
          next.pollStatus == StkPollStatus.success) {
        _showSuccessDialog();
      }
    });

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Subscription',
        showBackButton: true,
      ),
      body: state.isLoading && state.balance == null
          ? const LoadingIndicator(message: 'Loading subscription...')
          : RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  _buildBalanceHeader(state),
                  const SizedBox(height: 16),
                  _buildPlansSection(state, notifier),
                  const SizedBox(height: 8),
                  _buildSubscribePanel(state, notifier),
                  const SizedBox(height: 12),
                  _buildRedeemLink(),
                  const SizedBox(height: 20),
                  _buildPurchasesHeader(),
                  _buildPurchasesList(state),
                ],
              ),
            ),
    );
  }

  // ── Balance header (Hybrid: Unlimited line + Limited line) ──────────────────
  Widget _buildBalanceHeader(WalletState state) {
    final plans = state.balance?.plans ?? const <SubscriptionPlan>[];
    final unlimited = _firstUnlimited(plans);
    final limited = _firstLimited(plans);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF1DE9B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C853).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.card_membership, color: Colors.white70, size: 18),
              SizedBox(width: 6),
              Text(
                'BALANCE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _balanceLine(
            'Unlimited',
            unlimited != null
                ? _formatUnlimitedRemaining(unlimited.expiresAt!)
                : '0d 00h 00min',
          ),
          const SizedBox(height: 8),
          _balanceLine(
            'Limited',
            '${limited?.tokensRemaining ?? 0} Tokens',
          ),
        ],
      ),
    );
  }

  Widget _balanceLine(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  SubscriptionPlan? _firstUnlimited(List<SubscriptionPlan> plans) {
    for (final p in plans) {
      if (p.type == SubscriptionType.unlimited &&
          p.isActive &&
          p.expiresAt != null &&
          p.expiresAt!.isAfter(DateTime.now())) {
        return p;
      }
    }
    return null;
  }

  SubscriptionPlan? _firstLimited(List<SubscriptionPlan> plans) {
    for (final p in plans) {
      if (p.type == SubscriptionType.limited &&
          p.isActive &&
          (p.tokensRemaining ?? 0) > 0) {
        return p;
      }
    }
    return null;
  }

  String _formatUnlimitedRemaining(DateTime expiresAt) {
    final r = expiresAt.difference(DateTime.now());
    if (r.isNegative) return '0d 00h 00min';
    final d = r.inDays;
    final h = r.inHours.remainder(24);
    final m = r.inMinutes.remainder(60);
    return '${d}d ${h.toString().padLeft(2, '0')}h '
        '${m.toString().padLeft(2, '0')}min';
  }

  // ── Plans section (selectable cards) ────────────────────────────────────────
  Widget _buildPlansSection(WalletState state, WalletNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            'Subscription Plans',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        if (state.packages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('Loading plans...',
                    style: TextStyle(color: Colors.grey)),
              ),
            ),
          )
        else
          ...state.packages.map(
            (pkg) => _buildPlanCard(
              pkg,
              state.selectedPackageId == pkg.id,
              notifier,
            ),
          ),
      ],
    );
  }

  Widget _buildPlanCard(
    SubscriptionPackage pkg,
    bool isSelected,
    WalletNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: InkWell(
        onTap: () => notifier.selectPackage(pkg.id),
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
                    if (pkg.description != null &&
                        pkg.description!.isNotEmpty)
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
                      child: Icon(Icons.check_circle,
                          color: Color(0xFF00C853), size: 18),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Subscribe button + STK poll panel ───────────────────────────────────────
  Widget _buildSubscribePanel(WalletState state, WalletNotifier notifier) {
    final polling = state.isPurchasingSubscription ||
        state.pollStatus == StkPollStatus.polling;

    if (polling) {
      return _waitPanel(
        message: 'Check your phone for the M-Pesa PIN prompt. '
            'Enter your PIN to confirm the payment.',
        color: Colors.orange,
        showSpinner: true,
      );
    }

    void _openAirtimeSheet(WalletState state) async {
    SubscriptionPackage? pkg;
    for (final p in state.packages) {
      if (p.id == state.selectedPackageId) {
        pkg = p;
        break;
      }
    }
    if (pkg == null) return;
    await PayWithAirtimeSheet.show(context, pkg);
    // The sheet refreshes the wallet itself on a successful grant; nothing else
    // needed here. (state.packages / SubscriptionPackage are already imported.)
  }

    if (state.pollStatus == StkPollStatus.failed) {
      return _waitPanel(
        message: 'Payment was not successful. Please try again.',
        color: Colors.red,
        showSpinner: false,
        actions: [
          _retryButton(state, notifier),
        ],
      );
    }

    if (state.pollStatus == StkPollStatus.timeout) {
      return _waitPanel(
        message: "We didn't get a confirmation in time. If you completed the "
            'M-Pesa PIN, tap "I have paid". Otherwise try again.',
        color: Colors.orange,
        showSpinner: false,
        actions: [
          _retryButton(state, notifier),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: state.isConfirmingPayment ||
                      state.pendingPurchase == null
                  ? null
                  : () => notifier.confirmPayment(state.pendingPurchase!.id),
              icon: state.isConfirmingPayment
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, color: Colors.orange),
              label: const Text('I have paid',
                  style: TextStyle(color: Colors.orange)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }

    // idle / success → show the Subscribe (M-Pesa) + Pay-with-Airtime buttons.
    final hasSelection = state.selectedPackageId != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: hasSelection
                  ? () => notifier.subscribeAndPoll(
                        packageId: state.selectedPackageId!,
                      )
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'PAY WITH M-PESA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: hasSelection ? () => _openAirtimeSheet(state) : null,
              icon: const Icon(Icons.phone_android, color: Color(0xFF00C853)),
              label: const Text(
                'PAY WITH AIRTIME',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00C853),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF00C853)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _retryButton(WalletState state, WalletNotifier notifier) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: state.selectedPackageId == null
            ? null
            : () => notifier.subscribeAndPoll(
                  packageId: state.selectedPackageId!,
                ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C853),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text('Try Again',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _waitPanel({
    required String message,
    required Color color,
    required bool showSpinner,
    List<Widget> actions = const [],
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (showSpinner) ...[
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Icon(Icons.info_outline, color: color, size: 20),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...actions,
          ],
        ],
      ),
    );
  }

  // ── Redeem link ─────────────────────────────────────────────────────────────
  Widget _buildRedeemLink() {
    return Center(
      child: TextButton(
        onPressed: () => context.push('/redeem-coupon'),
        child: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Have a promo code? ',
                style: TextStyle(color: Colors.grey),
              ),
              TextSpan(
                text: 'Redeem here',
                style: TextStyle(
                  color: Color(0xFF00C853),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Purchase history (compact) ──────────────────────────────────────────────
  Widget _buildPurchasesHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        'Purchase History',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPurchasesList(WalletState state) {
    final purchases = state.purchases ?? const <SubscriptionPurchase>[];
    if (state.isLoading && purchases.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (purchases.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('No purchases yet',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: purchases.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == purchases.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildPurchaseItem(purchases[index]);
      },
    );
  }

  Widget _buildPurchaseItem(SubscriptionPurchase purchase) {
    final color = _statusColor(purchase.status);
    final pkgName = ref
            .read(walletNotifierProvider.notifier)
            .findPackageById(purchase.packageId)
            ?.name ??
        'Subscription';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.add_circle, color: color, size: 20),
        ),
        title: Text(pkgName,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          DateFormat('dd MMM yyyy, HH:mm').format(purchase.createdAt.toLocal()),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('KES ${purchase.amountPaid}',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                purchase.status.name.toUpperCase(),
                style: TextStyle(
                    fontSize: 9, color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(SubscriptionPurchaseStatus status) {
    switch (status) {
      case SubscriptionPurchaseStatus.completed:
        return Colors.green;
      case SubscriptionPurchaseStatus.pending:
        return Colors.orange;
      case SubscriptionPurchaseStatus.failed:
        return Colors.red;
      case SubscriptionPurchaseStatus.reversed:
        return Colors.grey;
    }
  }

  // ── Success dialog ──────────────────────────────────────────────────────────
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Icon(Icons.check_circle, size: 60, color: Colors.green),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Subscription Active!',
                style:
                    TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text('Your plan is now active.', textAlign: TextAlign.center),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                ref.read(walletNotifierProvider.notifier).resetPollStatus();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853)),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}