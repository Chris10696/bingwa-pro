// lib/features/customers/presentation/screens/customer_detail_screen.dart
// W4-batch-3b — Edit Customer (Hybrid EditCustomerScreen parity): edit name + account
// balance, blacklist/unblacklist, delete. Reached via /customers/:id (route unchanged).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/customer_model.dart';
import '../providers/customer_provider.dart';

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<CustomerDetailScreen> {
  static const _green = Color(0xFF00C853);
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(customerProvider.notifier).loadCustomer(widget.customerId));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _seed(Customer c) {
    if (_seeded) return;
    _nameController.text = c.name;
    _balanceController.text = c.accountBalance.toStringAsFixed(0);
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerProvider);
    final c = state.selectedCustomer;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBar(title: 'Edit Customer', showBackButton: true),
      body: c == null
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _content(c, state),
    );
  }

  Widget _content(Customer c, CustomerState state) {
    _seed(c);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0x1A00C853),
              child: Text(
                (c.name.isNotEmpty ? c.name[0] : '#').toUpperCase(),
                style: const TextStyle(
                    color: _green, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.phone,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  if (c.lastPurchaseTime != null)
                    Text(
                      'Last purchase: ${Formatters.formatDateTime(c.lastPurchaseTime!)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
            if (c.isBlackListed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Blacklisted',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
              labelText: 'Name', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _balanceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Account balance (Ksh)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: state.isUpdating ? null : () => _save(c),
            style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white),
            child: state.isUpdating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Update'),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: state.isBlacklisting ? null : () => _toggleBlacklist(c),
          icon: Icon(c.isBlackListed ? Icons.check_circle_outline : Icons.block,
              color: c.isBlackListed ? _green : Colors.orange),
          label: Text(
            c.isBlackListed ? 'Remove from blacklist' : 'Blacklist customer',
            style: TextStyle(color: c.isBlackListed ? _green : Colors.orange),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _confirmDelete(c),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          label: const Text('Delete customer',
              style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Future<void> _save(Customer c) async {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && name.length < 3) {
      _toast('Customer name should be at least 3 characters', Colors.red);
      return;
    }
    final balance = double.tryParse(_balanceController.text.trim());
    final result = await ref.read(customerProvider.notifier).updateCustomer(
          c.id,
          UpdateCustomerRequest(name: name, accountBalance: balance),
        );
    if (result != null) _toast('Customer updated successfully', _green);
  }

  Future<void> _toggleBlacklist(Customer c) async {
    final notifier = ref.read(customerProvider.notifier);
    final result = c.isBlackListed
        ? await notifier.unblacklistCustomer(c.id)
        : await notifier.blacklistCustomer(c.id);
    if (result != null) {
      _toast(
          result.isBlackListed
              ? 'Customer blacklisted'
              : 'Removed from blacklist',
          _green);
    }
  }

  Future<void> _confirmDelete(Customer c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete customer?'),
        content: Text(
            'Delete ${c.name.isEmpty ? c.phone : c.name}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final success =
        await ref.read(customerProvider.notifier).deleteCustomer(c.id);
    if (success && mounted) {
      _toast('Customer deleted successfully', _green);
      context.pop();
    }
  }

  void _toast(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }
}
