// lib/features/wallet/presentation/screens/wallet_screen.dart
// W1: minimum-fix per Q6.
//   - Token Balance card → Subscription Status card (plan-status readout)
//   - Stats row simplified to 2 cards (Lifetime Purchased / Lifetime Consumed)
//   - Hardcoded packages teaser → fed from state.packages (Q7)
//   - Transaction list now renders SubscriptionPurchase rows (Q5 rename)
//
// TODO(wave-2): redesign as subscription-plans list per Hybrid screenshot 1
//   (Balance header at top + plan rows + Subscribe button + promo code link).
//   W1 keeps the existing UI shell to avoid encroaching on W2's scope.
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

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Subscription',
        showBackButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/top-up'),
        backgroundColor: const Color(0xFF00C853),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Subscribe',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: state.isLoading && state.balance == null
          ? const LoadingIndicator(message: 'Loading wallet...')
          : RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  _buildSubscriptionStatusCard(state),
                  const SizedBox(height: 16),
                  _buildLifetimeStatsRow(state),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 16),
                  _buildPackagesTeaser(state),
                  const SizedBox(height: 16),
                  _buildPurchasesHeader(),
                  _buildPurchasesList(state),
                ],
              ),
            ),
    );
  }

  // ── Subscription status card (replaces Token Balance card) ─────────────────
  Widget _buildSubscriptionStatusCard(WalletState state) {
    final plans = state.balance?.plans ?? const <SubscriptionPlan>[];
    final unlimited = _firstUnlimited(plans);
    final limited = _firstLimited(plans);
    final hasAny = unlimited != null || limited != null;

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
                'SUBSCRIPTION STATUS',
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
          if (!hasAny)
            const Text(
              'No active plan',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          else ...[
            if (unlimited != null)
              Text(
                'Unlimited: ${_formatRemainingDuration(unlimited.expiresAt!)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            if (limited != null)
              Padding(
                padding: EdgeInsets.only(top: unlimited != null ? 6.0 : 0.0),
                child: Text(
                  'Tokens: ${limited.tokensRemaining}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasAny ? Icons.check_circle : Icons.info_outline,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  hasAny ? 'Active' : 'Subscribe to get started',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  String _formatRemainingDuration(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'expired';
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    if (days >= 1) return '${days}d ${hours}h';
    if (hours >= 1) return '${hours}h ${minutes}m';
    if (minutes >= 1) return '${minutes}m';
    return '<1m';
  }

  // ── Lifetime stats row — 2 cards (pending dropped from old 3-card layout) ──
  Widget _buildLifetimeStatsRow(WalletState state) {
    final purchased = state.balance?.wallet?.lifetimeTokensPurchased ?? 0;
    final consumed = state.balance?.wallet?.lifetimeTokensConsumed ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              label: 'Lifetime Purchased',
              value: '$purchased',
              icon: Icons.all_inclusive,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              label: 'Lifetime Consumed',
              value: '$consumed',
              icon: Icons.flash_on,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Quick actions ──────────────────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionTile(
              icon: Icons.add_circle_outline,
              label: 'Subscribe',
              color: const Color(0xFF00C853),
              onTap: () => context.push('/top-up'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionTile(
              icon: Icons.history,
              label: 'Transactions',
              color: Colors.blue,
              onTap: () => context.push('/transaction-history'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Packages teaser (Q7 — fed from state.packages) ─────────────────────────
  Widget _buildPackagesTeaser(WalletState state) {
    final packages = state.packages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subscription Plans',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => context.push('/top-up'),
                child: const Text(
                  'Subscribe',
                  style: TextStyle(color: Color(0xFF00C853)),
                ),
              ),
            ],
          ),
        ),
        if (packages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Loading plans...',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: packages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final pkg = packages[i];
                return InkWell(
                  onTap: () => context.push('/top-up'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.07),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C853)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pkg.type == SubscriptionType.unlimited
                                ? 'UNLIMITED'
                                : 'TOKENS',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF00C853),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          pkg.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          'KES ${pkg.price}',
                          style: const TextStyle(
                            color: Color(0xFF00C853),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── Purchases list (renamed from Token History) ────────────────────────────
  Widget _buildPurchasesHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Purchase History',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: () => context.push('/transaction-history'),
            child: const Text(
              'All Transactions',
              style: TextStyle(color: Color(0xFF00C853)),
            ),
          ),
        ],
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
            Icon(Icons.card_membership, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text(
              'No purchases yet',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Subscribe to a plan to start processing transactions',
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.push('/top-up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
              ),
              child: const Text('Subscribe Now'),
            ),
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
        return _buildPurchaseItem(purchases[index], state);
      },
    );
  }

  Widget _buildPurchaseItem(SubscriptionPurchase purchase, WalletState state) {
    final color = _statusColor(purchase.status);
    final pkgName =
        ref.read(walletNotifierProvider.notifier).findPackageById(purchase.packageId)?.name ??
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
        title: Text(
          pkgName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          DateFormat('dd MMM yyyy, HH:mm').format(purchase.createdAt),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'KES ${purchase.amountPaid}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                purchase.status.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
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
}