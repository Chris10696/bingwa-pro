// lib/features/wallet/presentation/widgets/pay_with_airtime_sheet.dart
//
// Pay-with-airtime (Sambaza) — TRUE Hybrid parity (MakePaymentViewModel.payWithAirtime).
//
// Flow (mirrors the decompiled payWithAirtime$1 → $1$1 → $1$1$1):
//   1. POST /transactions/airtime-subscription → backend builds a
//      SUBSCRIPTION_RENEWAL transaction whose ussdCode is the Sambaza transfer
//      *140*<price>*<adminNumber># (no token debit). [createSubscriptionOffer +
//      SUBSCRIPTION_RENEWAL transaction, server-side]
//   2. enqueueQuickDial(...) hands it to the SAME native pipeline every dial
//      uses (Express/Advanced, classify, status PATCH). [dialUssdUseCase.invoke]
//      customerPhone is '' so the pipeline does NOT auto-reply — the recipient
//      is inside the dial code already, and AutoReplySender.sendForType no-ops on
//      a blank phone (and Hybrid skips SUBSCRIPTION_RENEWAL anyway).
//   3. Poll GET /transactions/:id/status until terminal (Pro's stand-in for
//      observeTransactionStatusUseCase). FAILED + insufficient-balance →
//      "Insufficient airtime balance..." [isInsufficientBalanceResponse]
//   4. SUCCESS → POST /wallet/purchase-subscription-airtime grants the plan.
//      [addSubscriptionUseCase]
//
// Rides the same USSD engine as offers; a Sambaza is the simplest single-step,
// agent-initiated case. The grant trusts the dialed SUCCESS (Hybrid's model).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/session_bridge_service.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/models/subscription_package_model.dart';
import '../../../../shared/models/transaction_model.dart';
import '../../../../shared/repositories/transaction_repository.dart';
import '../../../../shared/repositories/wallet_repository.dart';
import '../providers/wallet_provider.dart';

enum _Phase { confirm, dialing, granting, success, error }

class PayWithAirtimeSheet extends ConsumerStatefulWidget {
  final SubscriptionPackage package;
  const PayWithAirtimeSheet({super.key, required this.package});

  /// Opens the sheet. Resolves to `true` if a plan was granted.
  static Future<bool?> show(BuildContext context, SubscriptionPackage pkg) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PayWithAirtimeSheet(package: pkg),
    );
  }

  @override
  ConsumerState<PayWithAirtimeSheet> createState() =>
      _PayWithAirtimeSheetState();
}

class _PayWithAirtimeSheetState extends ConsumerState<PayWithAirtimeSheet> {
  static const _green = Color(0xFF00C853);

  // Status-poll cadence + cap — same shape as quick_dial_provider.
  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _maxPolls = 60;
  static const Set<TransactionStatus> _terminal = {
    TransactionStatus.success,
    TransactionStatus.failed,
    TransactionStatus.failedAlreadyRecommended,
    TransactionStatus.failedOfferDeactivated,
    TransactionStatus.blocked,
  };

  _Phase _phase = _Phase.confirm;
  String? _error;

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _error = message;
    });
  }

  Future<void> _pay() async {
    setState(() {
      _phase = _Phase.dialing;
      _error = null;
    });
    try {
      // 1. Create the Sambaza transaction (no debit; ussdCode built server-side).
      final resp = await ref
          .read(transactionRepositoryProvider)
          .createAirtimeSubscription(packageId: widget.package.id);
      final sc = resp.statusCode ?? 0;
      if (sc < 200 || sc >= 300) {
        _fail(_extractMessage(resp.data) ?? 'Could not start the airtime payment.');
        return;
      }
      final data = resp.data;
      if (data is! Map) {
        _fail('Unexpected server response.');
        return;
      }
      final txnId = (data['id'] ?? '').toString();
      final ussdCode = (data['ussdCode'] ?? '').toString();
      final amount = _asInt(data['amount']);
      if (txnId.isEmpty || ussdCode.isEmpty) {
        _fail('Server did not return a dialable transaction.');
        return;
      }

      // 2. Enqueue into the real pipeline. customerPhone '' → no auto-reply.
      AppLogger.d('PayWithAirtime: enqueueing Sambaza txn=$txnId');
      final enqueued = await ref.read(sessionBridgeServiceProvider).enqueueQuickDial(
            transactionId: txnId,
            ussdCode: ussdCode,
            customerPhone: '',
            amount: amount,
          );
      if (!enqueued) {
        _fail('The dial could not start. Check that call permission is granted, '
            'then try again.');
        return;
      }

      // 3. Observe the dial outcome.
      final result = await _pollStatus(txnId);
      if (!mounted) return;
      if (result == null) {
        _fail('The airtime transfer is taking longer than usual. Check '
            'Transaction History — if it went through, your plan will be active.');
        return;
      }
      if (!result.$1) {
        // FAILED — surface the insufficient-balance case like Hybrid does.
        if (_isInsufficientBalance(result.$2)) {
          _fail('Insufficient airtime balance to complete your subscription.');
        } else {
          _fail(result.$2.isNotEmpty
              ? result.$2
              : 'The airtime transfer did not go through. Please try again.');
        }
        return;
      }

      // 4. SUCCESS → grant the plan, then refresh the wallet behind us.
      setState(() => _phase = _Phase.granting);
      await ref
          .read(walletRepositoryProvider)
          .purchaseSubscriptionWithAirtime(widget.package.id);
      await ref.read(walletNotifierProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _phase = _Phase.success);
    } catch (e) {
      _fail('Something went wrong. If the airtime was sent, check Transaction '
          'History before retrying.');
    }
  }

  /// Poll the transaction status until terminal → (success, responseText).
  Future<(bool, String)?> _pollStatus(String txnId) async {
    for (var i = 0; i < _maxPolls; i++) {
      await Future.delayed(_pollInterval);
      TransactionResponse status;
      try {
        status = await ref
            .read(transactionRepositoryProvider)
            .getTransactionStatus(txnId);
      } catch (_) {
        continue; // transient read error — keep polling
      }
      if (!_terminal.contains(status.status)) continue;
      final success = status.status == TransactionStatus.success;
      final text = (status.ussdResponse != null &&
              status.ussdResponse!.trim().isNotEmpty)
          ? status.ussdResponse!
          : (status.errorMessage ?? '');
      return (success, text);
    }
    return null;
  }

  bool _isInsufficientBalance(String msg) {
    final m = msg.toLowerCase();
    return m.contains('insufficient') ||
        m.contains('do not have enough') ||
        m.contains("don't have enough") ||
        m.contains('not enough');
  }

  String? _extractMessage(dynamic data) {
    if (data is Map && data['message'] != null) return data['message'].toString();
    return null;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return double.tryParse(v)?.toInt();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _buildBody(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.confirm:
        return _confirmView();
      case _Phase.dialing:
        return _busyView('Sending airtime via Safaricom...\nApprove the request '
            'on your phone if prompted.');
      case _Phase.granting:
        return _busyView('Airtime received — activating your subscription...');
      case _Phase.success:
        return _successView();
      case _Phase.error:
        return _errorView();
    }
  }

  Widget _confirmView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Pay with Airtime',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('${widget.package.name} · KES ${widget.package.price}',
            style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        Text(
          'KES ${widget.package.price} airtime will be sent from your line to '
          'activate this subscription. Make sure you have enough airtime, then '
          'tap below — your phone will dial the transfer automatically.',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _pay,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Pay with Airtime',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ),
      ],
    );
  }

  Widget _busyView(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _green),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, size: 64, color: _green),
        const SizedBox(height: 12),
        const Text('Subscription Active!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${widget.package.name} is now active on your account.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Widget _errorView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 56, color: Colors.red),
        const SizedBox(height: 12),
        Text(_error ?? 'Something went wrong.',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => setState(() => _phase = _Phase.confirm),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}