import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bingwa_pro/shared/models/transaction_model.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/transaction_execution_provider.dart';

class AirtimeScreen extends ConsumerStatefulWidget {
  const AirtimeScreen({super.key});

  @override
  ConsumerState<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends ConsumerState<AirtimeScreen> {
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionExecutionProvider.notifier).loadInitialData();
      ref.read(transactionExecutionProvider.notifier).selectTransactionType(TransactionType.airtime);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionExecutionProvider);
    final notifier = ref.read(transactionExecutionProvider.notifier);

    if (state.isLoading && state.availableProducts == null) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading products...'),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Airtime Top-up',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phone Number Input
              const Text(
                'Customer Phone Number',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  hintText: '0712 345 678',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: Validators.isValidSafaricomNumber,
                onChanged: notifier.updateCustomerPhone,
              ),
              const SizedBox(height: 30),

              // Product Selection
              const Text(
                'Select Airtime Amount',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              _buildProductGrid(state, notifier),
              const SizedBox(height: 20),

              // Or Custom Amount
              const Text(
                'Or enter custom amount',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  prefixText: 'KES ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final amount = double.tryParse(value) ?? 0.0;
                  notifier.updateAmount(amount);
                },
              ),
              const SizedBox(height: 30),

              // USSD Health Status
              if (state.ussdHealth != null) _buildUssdStatus(state.ussdHealth!),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () {
                          if (_formKey.currentState?.validate() == true) {
                            _confirmTransaction(context, state, notifier);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'PROCEED TO TRANSACTION',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              // Error Message
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid(TransactionExecutionState state, TransactionExecutionNotifier notifier) {
    final products = state.availableProducts
            ?.where((p) => p.type == TransactionType.airtime && p.isActive)
            .toList() ??
        [];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final isSelected = state.selectedProduct?.id == product.id;

        return GestureDetector(
          onTap: () {
            notifier.selectProduct(product);
            _amountController.text = product.price.toString();
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00C853).withOpacity(0.2)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF00C853) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF00C853) : Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  Formatters.formatCurrency(product.price),
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF00C853) : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUssdStatus(UssdHealthCheck health) {
    Color color;
    IconData icon;
    String status;

    if (health.status == UssdStatus.green) {
      color = Colors.green;
      icon = Icons.check_circle;
      status = 'System Normal';
    } else if (health.status == UssdStatus.yellow) {
      color = Colors.orange;
      icon = Icons.warning;
      status = 'Degraded Performance';
    } else if (health.status == UssdStatus.red) {
      color = Colors.red;
      icon = Icons.error;
      status = 'System Issues';
    } else {
      color = Colors.grey;
      icon = Icons.help;
      status = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'USSD System: $status',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                if (health.message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      health.message,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmTransaction(BuildContext context, TransactionExecutionState state, TransactionExecutionNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${state.customerPhone}'),
            Text('Amount: ${Formatters.formatCurrency(state.amount ?? 0)}'),
            if (state.selectedProduct != null)
              Text('Product: ${state.selectedProduct!.value}'),
            const SizedBox(height: 20),
            const Text(
              'Are you sure you want to proceed?',
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
              await notifier.executeTransaction();

              if (mounted && state.showConfirmation && state.lastResponse != null) {
                _showTransactionResult(context, state.lastResponse!);
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

  void _showTransactionResult(BuildContext context, TransactionResponse response) {
    final isSuccess = response.status == TransactionStatus.success;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          size: 60,
          color: isSuccess ? Colors.green : Colors.red,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isSuccess ? 'Transaction Successful!' : 'Transaction Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              response.errorMessage ?? 'Reference: ${response.reference}',
              textAlign: TextAlign.center,
            ),
            if (response.balanceAfter != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'New Balance: ${Formatters.formatCurrency(response.balanceAfter!)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(transactionExecutionProvider.notifier).clearConfirmation();
                if (isSuccess) {
                  context.pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}