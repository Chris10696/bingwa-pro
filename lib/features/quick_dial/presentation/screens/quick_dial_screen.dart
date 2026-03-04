import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/logger.dart';
import '../../../../shared/models/transaction_model.dart';
import '../../../../shared/repositories/transaction_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

// Quick Dial Product Model with transaction type
class QuickDialProduct {
  final String id;
  final String name;
  final String value;
  final double price;
  final String ussdCode;
  final TransactionType type;
  final bool isActive;

  QuickDialProduct({
    required this.id,
    required this.name,
    required this.value,
    required this.price,
    required this.ussdCode,
    required this.type,
    this.isActive = true,
  });
}

// Enhanced mock data with transaction types
final List<QuickDialProduct> mockProducts = [
  // Data bundles
  QuickDialProduct(
    id: '1',
    name: '1.5 GB - 3 Hrs',
    value: '1.5GB',
    price: 50,
    ussdCode: '*180*5*2*BH*1*1#',
    type: TransactionType.data,
  ),
  QuickDialProduct(
    id: '2',
    name: '350 MBS - 7 Days',
    value: '350MB',
    price: 47,
    ussdCode: '*180*5*2*BH*2*1#',
    type: TransactionType.data,
  ),
  QuickDialProduct(
    id: '3',
    name: '2.5GB - 7 Days',
    value: '2.5GB',
    price: 100,
    ussdCode: '*180*5*2*BH*3*1#',
    type: TransactionType.data,
  ),
  QuickDialProduct(
    id: '4',
    name: '6GB - 7 Days',
    value: '6GB',
    price: 200,
    ussdCode: '*180*5*2*BH*4*1#',
    type: TransactionType.data,
  ),
  QuickDialProduct(
    id: '5',
    name: '1GB - 1Hr',
    value: '1GB',
    price: 19,
    ussdCode: '*180*5*2*BH*5*1#',
    type: TransactionType.data,
  ),
  QuickDialProduct(
    id: '6',
    name: '250MBS - 24 Hrs',
    value: '250MB',
    price: 20,
    ussdCode: '*180*5*2*BH*6*1#',
    type: TransactionType.data,
  ),
  QuickDialProduct(
    id: '7',
    name: '1GB - 24 Hrs',
    value: '1GB',
    price: 50,
    ussdCode: '*180*5*2*BH*7*1#',
    type: TransactionType.data,
  ),
  QuickDialProduct(
    id: '8',
    name: '1.25GB - Until Midnight',
    value: '1.25GB',
    price: 30,
    ussdCode: '*180*5*2*BH*8*1#',
    type: TransactionType.data,
  ),
  // Airtime products
  QuickDialProduct(
    id: '9',
    name: 'Airtime - KES 10',
    value: 'KES 10',
    price: 10,
    ussdCode: '*334#',
    type: TransactionType.airtime,
  ),
  QuickDialProduct(
    id: '10',
    name: 'Airtime - KES 20',
    value: 'KES 20',
    price: 20,
    ussdCode: '*334#',
    type: TransactionType.airtime,
  ),
  QuickDialProduct(
    id: '11',
    name: 'Airtime - KES 50',
    value: 'KES 50',
    price: 50,
    ussdCode: '*334#',
    type: TransactionType.airtime,
  ),
  QuickDialProduct(
    id: '12',
    name: 'Airtime - KES 100',
    value: 'KES 100',
    price: 100,
    ussdCode: '*334#',
    type: TransactionType.airtime,
  ),
];

class QuickDialScreen extends ConsumerStatefulWidget {
  const QuickDialScreen({super.key});

  @override
  ConsumerState<QuickDialScreen> createState() => _QuickDialScreenState();
}

class _QuickDialScreenState extends ConsumerState<QuickDialScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedProductId;
  bool _isSearching = false;
  bool _isProcessing = false;
  List<QuickDialProduct> _filteredProducts = mockProducts;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    // Could implement customer lookup here
  }

  void _filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = mockProducts;
        _isSearching = false;
      } else {
        _filteredProducts = mockProducts
            .where((product) =>
                product.name.toLowerCase().contains(query.toLowerCase()) ||
                product.value.toLowerCase().contains(query.toLowerCase()))
            .toList();
        _isSearching = true;
      }
    });
  }

  Future<String> _getDeviceId() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.id;
    } catch (e) {
      return 'quick_dial_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _executeQuickDial() async {
    if (_phoneController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter customer phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedProductId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a product'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final selectedProduct = mockProducts.firstWhere(
      (p) => p.id == _selectedProductId,
    );

    // Show confirmation dialog
    if (!mounted) return;
    _showConfirmationDialog(selectedProduct);
  }

  void _showConfirmationDialog(QuickDialProduct product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Quick Dial'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${_phoneController.text}'),
            const SizedBox(height: 8),
            Text('Product: ${product.name}'),
            Text('Price: ${Formatters.formatCurrency(product.price)}'),
            const SizedBox(height: 8),
            Text('USSD: ${product.ussdCode}'),
            const SizedBox(height: 16),
            const Text(
              'This will execute a manual repurchase for this customer.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _executeUssd(product);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            child: const Text('Execute'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeUssd(QuickDialProduct product) async {
    setState(() => _isProcessing = true);

    // Check if widget is still mounted
    if (!mounted) return;

    // Show loading dialog
    BuildContext? loadingContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        loadingContext = dialogContext;
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Get agent ID from auth state
      final authState = ref.read(authNotifierProvider);
      final agentId = authState.agent?.id ?? '';
      
      if (agentId.isEmpty) {
        throw Exception('Agent ID not found. Please login again.');
      }

      // Get device ID
      final deviceId = await _getDeviceId();

      // Create transaction request
      final request = TransactionRequest(
        agentId: agentId,
        type: product.type,
        customerPhone: _phoneController.text,
        amount: product.price,
        productId: product.id,
        productName: product.name,
        bundleSize: product.value,
        ussdCode: product.ussdCode,
        deviceId: deviceId,
        metadata: {
          'quick_dial': true,
          'original_product': product.name,
        },
      );

      // Execute based on product type
      final repository = ref.read(transactionRepositoryProvider);
      TransactionResponse response;
      
      switch (product.type) {
        case TransactionType.airtime:
          response = await repository.executeAirtime(request);
          break;
        case TransactionType.data:
          response = await repository.executeData(request);
          break;
        case TransactionType.sms:
          response = await repository.executeSms(request);
          break;
        case TransactionType.minutes:
        case TransactionType.bundle:
          // Fallback to airtime for unsupported types
          response = await repository.executeAirtime(request);
          break;
      }

      // Close loading dialog
      if (loadingContext != null && mounted) {
        Navigator.pop(loadingContext!);
      }

      if (!mounted) return;

      // Show result dialog
      final isSuccess = response.status == TransactionStatus.success;
      _showResultDialog(isSuccess, response);
      
      // If successful, refresh transaction history
      if (isSuccess) {
        ref.read(transactionProvider.notifier).refreshTransactions();
      }
      
    } catch (e) {
      AppLogger.e('Quick dial failed:', e);
      
      // Close loading dialog
      if (loadingContext != null && mounted) {
        Navigator.pop(loadingContext!);
      }

      if (!mounted) return;
      
      // Show error dialog
      _showResultDialog(false, null, error: e.toString());
      
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showResultDialog(bool success, TransactionResponse? response, {String? error}) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Icon(
          success ? Icons.check_circle : Icons.error,
          size: 60,
          color: success ? Colors.green : Colors.red,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                success ? 'Transaction Successful!' : 'Transaction Failed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: success ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 10),
              if (success && response != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildResultRow('Reference', response.reference),
                      _buildResultRow('Amount', Formatters.formatCurrency(response.amount)),
                      if (response.tokenDeduction > 0)
                        _buildResultRow('Tokens', response.tokenDeduction.toString()),
                      if (response.commission > 0)
                        _buildResultRow('Commission', Formatters.formatCurrency(response.commission)),
                      if (response.balanceAfter != null)
                        _buildResultRow('New Balance', Formatters.formatCurrency(response.balanceAfter!)),
                    ],
                  ),
                ),
              ] else if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ] else ...[
                const Text('Transaction failed. Please try again.'),
              ],
            ],
          ),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                if (success && mounted) {
                  _clearForm();
                  // Navigate to transaction history to see the result
                  context.push('/transaction-history');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C853),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              ),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    setState(() {
      _phoneController.clear();
      _selectedProductId = null;
      _isProcessing = false;
    });
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Quick Dial',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Search/Filter Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _filterProducts,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _filterProducts('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Phone Number Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !_isProcessing,
              decoration: InputDecoration(
                labelText: 'Customer Phone Number',
                hintText: '07XX XXX XXX',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: _isProcessing,
                fillColor: _isProcessing ? Colors.grey[100] : null,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Products Grid
          Expanded(
            child: _isProcessing
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing transaction...'),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final isSelected = _selectedProductId == product.id;

                      return GestureDetector(
                        onTap: _isProcessing ? null : () {
                          setState(() {
                            _selectedProductId = product.id;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF00C853).withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF00C853)
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00C853).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getTypeColor(product.type).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        product.type.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _getTypeColor(product.type),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      product.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected
                                            ? const Color(0xFF00C853)
                                            : Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      Formatters.formatCurrency(product.price),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFF00C853)
                                            : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        product.ussdCode,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF00C853),
                                        size: 18,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Execute Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _executeQuickDial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'EXECUTE QUICK DIAL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.airtime:
        return Colors.green;
      case TransactionType.data:
        return Colors.blue;
      case TransactionType.sms:
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }
}