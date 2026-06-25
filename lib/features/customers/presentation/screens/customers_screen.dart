// lib/features/customers/presentation/screens/customers_screen.dart
// W4-batch-3b — "My Customers" (Hybrid MyCustomersScreen parity): a searchable list of the
// agent's customers (name, phone, balance, last purchase). Tap a row → Edit Customer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/customer_model.dart';
import '../providers/customer_provider.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  static const _green = Color(0xFF00C853);
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(customerProvider.notifier).loadCustomers());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerProvider);
    final q = _query.trim().toLowerCase();
    final customers = q.isEmpty
        ? state.customers
        : state.customers
            .where((c) =>
                c.name.toLowerCase().contains(q) || c.phone.contains(q))
            .toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBar(title: 'My Customers', showBackButton: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _body(state, customers)),
        ],
      ),
    );
  }

  Widget _body(CustomerState state, List<Customer> customers) {
    if (state.isLoading && state.customers.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _green));
    }
    if (customers.isEmpty) return _empty();
    return RefreshIndicator(
      color: _green,
      onRefresh: () => ref.read(customerProvider.notifier).loadCustomers(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: customers.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final c = customers[i];
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0x1A00C853),
                child: Text(
                  (c.name.isNotEmpty ? c.name[0] : '#').toUpperCase(),
                  style: const TextStyle(
                      color: _green, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(c.name.isEmpty ? c.phone : c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(c.phone),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Ksh ${c.accountBalance.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (c.lastPurchaseTime != null)
                    Text(Formatters.formatDate(c.lastPurchaseTime!),
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
              onTap: () => context.push('/customers/${c.id}'),
            ),
          );
        },
      ),
    );
  }

  Widget _empty() {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Center(
          child: Text('No customers yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text('Customers appear here after their first payment',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54)),
        ),
      ],
    );
  }
}
