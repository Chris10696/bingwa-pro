// lib/features/settings/presentation/screens/till_registration_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class TillRegistrationScreen extends ConsumerStatefulWidget {
  const TillRegistrationScreen({super.key});

  @override
  ConsumerState<TillRegistrationScreen> createState() => _TillRegistrationScreenState();
}

class _TillRegistrationScreenState extends ConsumerState<TillRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tillController = TextEditingController();
  final _paybillController = TextEditingController();
  final _accountController = TextEditingController();
  String _selectedMethod = 'till';
  bool _autoDetect = true;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final agent = authState.agent;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Payment Settings',
        showBackButton: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Settings Required',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Set up your payment method to start processing customer payments',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Payment Method Selection
              const Text(
                'Select Payment Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildPaymentMethodCard(
                value: 'till',
                title: 'M-PESA Till Number',
                description: 'Customers pay directly to your till',
                icon: Icons.store,
                isSelected: _selectedMethod == 'till',
                onTap: () => setState(() => _selectedMethod = 'till'),
              ),
              const SizedBox(height: 12),
              _buildPaymentMethodCard(
                value: 'paybill',
                title: 'M-PESA PayBill',
                description: 'Use PayBill with account number',
                icon: Icons.account_balance,
                isSelected: _selectedMethod == 'paybill',
                onTap: () => setState(() => _selectedMethod = 'paybill'),
              ),
              const SizedBox(height: 12),
              _buildPaymentMethodCard(
                value: 'both',
                title: 'Both Till & PayBill',
                description: 'Accept payments via both methods',
                icon: Icons.compare_arrows,
                isSelected: _selectedMethod == 'both',
                onTap: () => setState(() => _selectedMethod = 'both'),
              ),

              const SizedBox(height: 30),

              // Till Number Field
              if (_selectedMethod == 'till' || _selectedMethod == 'both')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Till Number',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _tillController,
                      decoration: InputDecoration(
                        hintText: 'Enter your till number',
                        prefixText: agent?.tillNumber != null ? '${agent?.tillNumber} - ' : '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if ((_selectedMethod == 'till' || _selectedMethod == 'both') && 
                            (value == null || value.isEmpty)) {
                          return 'Please enter your till number';
                        }
                        if (value != null && value.isNotEmpty && value.length != 6) {
                          return 'Till number should be 6 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              // PayBill Fields
              if (_selectedMethod == 'paybill' || _selectedMethod == 'both')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PayBill Number',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _paybillController,
                      decoration: InputDecoration(
                        hintText: 'Enter PayBill number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if ((_selectedMethod == 'paybill' || _selectedMethod == 'both') && 
                            (value == null || value.isEmpty)) {
                          return 'Please enter PayBill number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Account Number (Optional)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _accountController,
                      decoration: InputDecoration(
                        hintText: 'Enter your account number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),

              // Auto-detect toggle - FIXED: Use activeTrackColor instead of activeColor
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Auto-detect payments',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Automatically detect and process customer payments',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _autoDetect,
                      onChanged: (value) => setState(() => _autoDetect = value),
                      activeTrackColor: const Color(0xFF00C853), // FIXED: Use activeTrackColor
                      activeColor: Colors.white,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitTillInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'SAVE PAYMENT SETTINGS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Verification Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your payment details will be verified. You\'ll receive a small test payment to confirm.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required String value,
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF00C853) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? const Color(0xFF00C853).withValues(alpha: 0.05) : null, // FIXED: withOpacity → withValues
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFF00C853).withValues(alpha: 0.1) // FIXED: withOpacity → withValues
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF00C853) : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF00C853) : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // Custom radio button
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF00C853) : Colors.grey.shade400,
                  width: 2,
                ),
                color: isSelected 
                    ? const Color(0xFF00C853).withValues(alpha: 0.1) // FIXED: withOpacity → withValues
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C853),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            )
          ],
        ),
      ),
    );
  }

  Future<void> _submitTillInfo() async {
    if (!_formKey.currentState!.validate()) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Call API to update agent's payment settings
      await ref.read(authNotifierProvider.notifier).updatePaymentSettings(
        tillNumber: _tillController.text.isNotEmpty ? _tillController.text : null,
        paybillNumber: _paybillController.text.isNotEmpty ? _paybillController.text : null,
        paybillAccount: _accountController.text.isNotEmpty ? _accountController.text : null,
        method: _selectedMethod,
        autoDetect: _autoDetect,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      // Show success
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Settings Saved!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your payment settings have been saved and will be verified shortly.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (mounted) context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}