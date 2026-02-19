import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:formz/formz.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/wallet_model.dart';
import '../providers/wallet_provider.dart';

class AmountInput extends FormzInput<String, String> {
  const AmountInput.pure() : super.pure('');
  const AmountInput.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String? value) {
    return Validators.isValidAmount(
      value,
      min: 100.0,
      max: 100000.0,
    );
  }
}

class TopUpScreen extends ConsumerStatefulWidget {
  const TopUpScreen({super.key});

  @override
  ConsumerState<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends ConsumerState<TopUpScreen> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  // Removed _selectedMethod as it's not used

  @override
  void initState() {
    super.initState();
    // Load payment methods
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletNotifierProvider.notifier).loadWalletData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletNotifierProvider);
    final notifier = ref.read(walletNotifierProvider.notifier);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Top Up Tokens',
        showBackButton: true,
      ),
      body: state.isLoading && state.paymentMethods == null
          ? const LoadingIndicator(message: 'Loading payment methods...')
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter Amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        hintText: 'Enter amount in KES',
                        prefixText: 'KES ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        errorText: AmountInput.dirty(_amountController.text)
                            .error,
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {});
                      },
                      validator: (value) => AmountInput.dirty(value ?? '').error,
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Select Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildPaymentMethods(state),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: state.isPurchasingTokens
                            ? null
                            : () {
                                if (_formKey.currentState?.validate() == true) {
                                  _proceedToPayment(state, notifier);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C853),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: state.isPurchasingTokens
                            ? const ButtonLoadingIndicator()
                            : const Text(
                                'PROCEED TO PAYMENT',
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
            ),
    );
  }

  Widget _buildPaymentMethods(WalletState state) {
    final methods = state.paymentMethods ?? [];
    final selectedMethod = state.selectedPaymentMethod;

    return Column(
      children: methods.map((method) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: _PaymentMethodRadio(
            method: method,
            isSelected: method.type == selectedMethod,
            onSelected: (value) {
              ref.read(walletNotifierProvider.notifier).selectPaymentMethod(value);
            },
          ),
        );
      }).toList(),
    );
  }

  IconData _getPaymentMethodIcon(String type) {
    switch (type) {
      case 'MPESA_TILL':
      case 'MPESA_PAYBILL':
        return Icons.phone_android;
      case 'AIRTIME':
        return Icons.phone;
      case 'BANK_TRANSFER':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  void _proceedToPayment(WalletState state, WalletNotifier notifier) {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final method = state.selectedPaymentMethod;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${Formatters.formatCurrency(amount)}'),
            Text('Method: ${_getMethodDisplayName(method)}'),
            const SizedBox(height: 20),
            const Text(
              'Are you sure you want to proceed with this payment?',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await notifier.purchaseTokens(
                amount: amount,
                paymentMethod: method,
              );

              // Check if there's a pending transaction
              if (mounted && state.pendingTransaction != null) {
                _showPaymentInstructions(context, state);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _getMethodDisplayName(String type) {
    switch (type) {
      case 'MPESA_TILL':
        return 'M-Pesa Till Number';
      case 'MPESA_PAYBILL':
        return 'M-Pesa PayBill';
      case 'AIRTIME':
        return 'Airtime Transfer';
      default:
        return type;
    }
  }

  void _showPaymentInstructions(BuildContext context, WalletState state) {
    final transaction = state.pendingTransaction;
    final method = state.selectedPaymentMethod;

    String instructions = '';

    switch (method) {
      case 'MPESA_TILL':
        instructions = '1. Go to M-Pesa on your phone\n'
            '2. Select "Pay Bill"\n'
            '3. Enter Business No: 123456\n'
            '4. Enter Account No: ${transaction?.reference}\n'
            '5. Enter Amount: ${_amountController.text}\n'
            '6. Enter your M-Pesa PIN\n'
            '7. Wait for confirmation';
        break;
      case 'MPESA_PAYBILL':
        instructions = '1. Go to M-Pesa on your phone\n'
            '2. Select "Pay Bill"\n'
            '3. Enter Business No: 987654\n'
            '4. Enter Account No: ${transaction?.reference}\n'
            '5. Enter Amount: ${_amountController.text}\n'
            '6. Enter your M-Pesa PIN\n'
            '7. Wait for confirmation';
        break;
      case 'AIRTIME':
        instructions = '1. Dial *144# on your phone\n'
            '2. Select "Airtime Transfer"\n'
            '3. Enter Agent No: 0712345678\n'
            '4. Enter Amount: ${_amountController.text}\n'
            '5. Confirm transaction\n'
            '6. Wait for confirmation';
        break;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Instructions'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please follow these steps to complete your payment:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Text(instructions),
              const SizedBox(height: 20),
              const Text(
                'Once payment is complete, click "I have paid" below.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (transaction != null) {
                _confirmPayment(transaction.id);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            child: const Text('I have paid'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPayment(String transactionId) async {
    final notifier = ref.read(walletNotifierProvider.notifier);
    await notifier.confirmPayment(transactionId);

    // Check if payment was successful
    final state = ref.read(walletNotifierProvider);
    final transaction = state.transactions?.firstWhere(
      (t) => t.id == transactionId,
    );

    // Handle null case
    if (transaction == null) {
      _showTransactionNotFoundDialog();
      return;
    }

    if (transaction.status == WalletTransactionStatus.success) {
      _showSuccessDialog();
    } else if (transaction.status == WalletTransactionStatus.failed) {
      _showFailureDialog();
    }
  }

  void _showTransactionNotFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(
          Icons.warning,
          size: 60,
          color: Colors.orange,
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Transaction Not Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Unable to find the transaction. Please check your transaction history.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(
          Icons.check_circle,
          size: 60,
          color: Colors.green,
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Your tokens have been added to your wallet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
              ),
              child: const Text('Back to Wallet'),
            ),
          ),
        ],
      ),
    );
  }

  void _showFailureDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(
          Icons.error,
          size: 60,
          color: Colors.red,
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Payment Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
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

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}

// New widget to handle the updated Radio API
class _PaymentMethodRadio extends StatelessWidget {
  final PaymentMethod method;
  final bool isSelected;
  final ValueChanged<String> onSelected;

  const _PaymentMethodRadio({
    required this.method,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Radio<String>(
            value: method.type,
            groupValue: isSelected ? method.type : null,
            onChanged: (value) {
              if (value != null) {
                onSelected(value);
              }
            },
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getPaymentMethodIcon(method.type),
              color: const Color(0xFF00C853),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
                if (method.description != null && method.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      method.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentMethodIcon(String type) {
    switch (type) {
      case 'MPESA_TILL':
      case 'MPESA_PAYBILL':
        return Icons.phone_android;
      case 'AIRTIME':
        return Icons.phone;
      case 'BANK_TRANSFER':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }
}