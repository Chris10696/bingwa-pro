import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';

// Auto Renewal Model
class AutoRenewal {
  final String id;
  final String customerName;
  final String customerPhone;
  final String productName;
  final String productValue;
  final double amount;
  final String frequency; // daily, weekly, monthly
  final DateTime nextBillingDate;
  final bool isActive;
  final DateTime createdAt;

  AutoRenewal({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.productName,
    required this.productValue,
    required this.amount,
    required this.frequency,
    required this.nextBillingDate,
    required this.isActive,
    required this.createdAt,
  });
}

// Mock data for auto renewals
final List<AutoRenewal> mockRenewals = [
  AutoRenewal(
    id: '1',
    customerName: 'John Doe',
    customerPhone: '0712345678',
    productName: '1GB Daily Bundle',
    productValue: '1GB',
    amount: 200,
    frequency: 'daily',
    nextBillingDate: DateTime.now().add(const Duration(days: 1)),
    isActive: true,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  AutoRenewal(
    id: '2',
    customerName: 'Jane Smith',
    customerPhone: '0723456789',
    productName: '3GB Weekly Bundle',
    productValue: '3GB',
    amount: 500,
    frequency: 'weekly',
    nextBillingDate: DateTime.now().add(const Duration(days: 3)),
    isActive: true,
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
  ),
];

// Available products for auto renewal
final List<Map<String, dynamic>> availableProducts = [
  {
    'id': 'p1',
    'name': '1GB Daily Bundle',
    'value': '1GB',
    'price': 200,
    'frequency': 'daily',
  },
  {
    'id': 'p2',
    'name': '3GB Weekly Bundle',
    'value': '3GB',
    'price': 500,
    'frequency': 'weekly',
  },
  {
    'id': 'p3',
    'name': '10GB Monthly Bundle',
    'value': '10GB',
    'price': 1000,
    'frequency': 'monthly',
  },
];

class AutoRenewalsScreen extends ConsumerStatefulWidget {
  const AutoRenewalsScreen({super.key});

  @override
  ConsumerState<AutoRenewalsScreen> createState() => _AutoRenewalsScreenState();
}

class _AutoRenewalsScreenState extends ConsumerState<AutoRenewalsScreen> {
  int _selectedIndex = 0; // 0: Active, 1: Paused, 2: History

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Auto Renewals',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: Row(
              children: [
                _buildTab('Active', 0),
                _buildTab('Paused', 1),
                _buildTab('History', 2),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddRenewalDialog,
        backgroundColor: const Color(0xFF00C853),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? const Color(0xFF00C853) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? const Color(0xFF00C853) : Colors.grey,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) {
      return _buildRenewalList(mockRenewals.where((r) => r.isActive).toList());
    } else if (_selectedIndex == 1) {
      return _buildRenewalList(mockRenewals.where((r) => !r.isActive).toList());
    } else {
      return _buildHistoryList();
    }
  }

  Widget _buildRenewalList(List<AutoRenewal> renewals) {
    if (renewals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.autorenew,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No auto renewals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create a new auto renewal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: renewals.length,
      itemBuilder: (context, index) {
        final renewal = renewals[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            renewal.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            renewal.customerPhone,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: renewal.isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        renewal.isActive ? 'Active' : 'Paused',
                        style: TextStyle(
                          color: renewal.isActive ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.wifi,
                        '${renewal.productValue} - ${renewal.productName}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.attach_money,
                        Formatters.formatCurrency(renewal.amount),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInfoChip(
                        Icons.update,
                        renewal.frequency,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoChip(
                        Icons.schedule,
                        'Next: ${_formatDate(renewal.nextBillingDate)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _toggleRenewal(renewal.id),
                      style: TextButton.styleFrom(
                        foregroundColor: renewal.isActive ? Colors.red : Colors.green,
                      ),
                      child: Text(renewal.isActive ? 'Pause' : 'Activate'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showEditRenewalDialog(renewal),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                      ),
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    return const Center(
      child: Text('History coming soon'),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRenewalDialog() {
    final formKey = GlobalKey<FormState>();
    String customerName = '';
    String customerPhone = '';
    String selectedProductId = availableProducts.first['id'] as String;
    double? amount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Auto Renewal'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Customer Name',
                    border: OutlineInputBorder(),
                  ),
                  onSaved: (value) => customerName = value ?? '',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter customer name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Customer Phone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  onSaved: (value) => customerPhone = value ?? '',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter customer phone';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // FIXED: Explicitly typed DropdownButtonFormField<String>
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Product',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedProductId,
                  items: availableProducts.map<DropdownMenuItem<String>>((product) {
                    return DropdownMenuItem<String>(
                      value: product['id'] as String,
                      child: Text(product['name'] as String),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    if (value != null) {
                      selectedProductId = value;
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                Navigator.pop(context);
                _createAutoRenewal(
                  customerName,
                  customerPhone,
                  selectedProductId,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditRenewalDialog(AutoRenewal renewal) {
    // Similar to add dialog but pre-filled
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit feature coming soon'),
      ),
    );
  }

  void _toggleRenewal(String id) {
    // Toggle renewal active status
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Toggled renewal $id'),
      ),
    );
  }

  void _createAutoRenewal(String name, String phone, String productId) {
    // Create new auto renewal
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto renewal created successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}