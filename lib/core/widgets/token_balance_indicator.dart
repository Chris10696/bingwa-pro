// lib/core/widgets/token_balance_indicator.dart
// W1 new widget. Per Q7 lock: 24dp circular token icon in the dashboard app
// bar. Color: theme's onSurfaceVariant when hasUsableTokens=true (subtle),
// theme's tertiary when false (warning). No badge/count/animation/tooltip in
// W1. Tap routes to /wallet.
//
// Reads hasUsableTokens from walletNotifierProvider (not yet wired here —
// the dashboard app bar receives this widget and the provider import lives
// at the consumer site to avoid a circular dependency between core/ and
// features/wallet/).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 24dp app-bar indicator showing whether the agent has at least one usable
/// subscription plan. Hides the underlying token-state from the user; only
/// signals "good" (subtle) or "needs attention" (amber-ish).
class TokenBalanceIndicator extends ConsumerWidget {
  /// Reads hasUsableTokens via the provided [hasUsableTokens] selector.
  /// The dashboard wires this to `ref.watch(walletNotifierProvider.select((s) =>
  /// s.balance?.hasUsableTokens ?? false))` to avoid a hard import dependency
  /// from core/ to features/wallet/.
  final bool hasUsableTokens;

  const TokenBalanceIndicator({
    super.key,
    required this.hasUsableTokens,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // W1: explicit colors. The Theme's onSurfaceVariant/tertiary colors blend
    // against the green app bar, so we use explicit high-contrast colors that
    // work specifically in this app-bar context.
    final Color color = hasUsableTokens
        ? Colors.white                  // hasUsableTokens=true: subtle white
        : const Color(0xFFFFB300);      // hasUsableTokens=false: amber warning

    return IconButton(
      icon: Icon(
        Icons.token,
        size: 24,
        color: color,
      ),
      tooltip: null,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: const BoxConstraints(),
      onPressed: () => context.push('/wallet'),
    );
  }
}