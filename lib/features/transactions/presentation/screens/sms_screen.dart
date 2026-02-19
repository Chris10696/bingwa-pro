import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/formatters.dart';
import 'package:bingwa_pro/shared/models/transaction_model.dart';
import '../providers/transaction_execution_provider.dart';

class SMSScreen extends ConsumerStatefulWidget {
  const SMSScreen({super.key});

  @override
  ConsumerState<SMSScreen> createState() => _SMSScreenState();
}

class _SMSScreenState extends ConsumerState<SMSScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionExecutionProvider.notifier).loadInitialData();
      ref.read(transactionExecutionProvider.notifier)
          .selectTransactionType(TransactionType.sms);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionExecutionProvider);
    final notifier = ref.read(transactionExecutionProvider.notifier);

    if (state.isLoading && state.availableProducts == null) {
      return const Scaffold(
        body: LoadingIndicator(message: 'Loading SMS bundles...'),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'SMS Bundle',
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

              // SMS Bundle Selection
              const Text(
                'Select SMS Bundle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              _buildBundleList(state, notifier),
              const SizedBox(height: 30),

              // USSD Health Status
              if (state.ussdHealth != null) _buildUssdStatus(state.ussdHealth!),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: state.isSubmitting || state.selectedProduct == null
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
                      ? const ButtonLoadingIndicator()
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

  Widget _buildBundleList(TransactionExecutionState state, TransactionExecutionNotifier notifier) {
    final bundles = state.availableProducts
            ?.where((p) => p.type == TransactionType.sms && p.isActive)
            .toList() ??
        [];

    if (bundles.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Text(
            'No SMS bundles available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: bundles.map((bundle) {
        final isSelected = state.selectedProduct?.id == bundle.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          color: isSelected ? const Color(0xFF00C853).withAlpha(25) : null,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00C853) : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.message,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
            title: Text(
              bundle.name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected ? const Color(0xFF00C853) : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bundle.value),
                if (bundle.validityDays > 0)
                  Text('Valid for ${bundle.validityDays} days'),
              ],
            ),
            trailing: Text(
              Formatters.formatCurrency(bundle.price),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected ? const Color(0xFF00C853) : Colors.black,
              ),
            ),
            onTap: () {
              notifier.selectProduct(bundle);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUssdStatus(UssdHealthCheck health) {
    Color color;
    IconData icon;
    String status;

    switch (health.status) {
      case UssdStatus.green:
        color = Colors.green;
        icon = Icons.check_circle;
        status = 'System Normal';
        break;
      case UssdStatus.yellow:
        color = Colors.orange;
        icon = Icons.warning;
        status = 'Degraded Performance';
        break;
      case UssdStatus.red:
        color = Colors.red;
        icon = Icons.error;
        status = 'System Issues';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
        status = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(75)),
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
            if (state.selectedProduct != null) ...[
              Text('Bundle: ${state.selectedProduct!.value}'),
              Text('Price: ${Formatters.formatCurrency(state.selectedProduct!.price)}'),
            ],
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
    super.dispose();
  }
}