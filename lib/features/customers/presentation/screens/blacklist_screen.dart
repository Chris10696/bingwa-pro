// lib/features/customers/presentation/screens/blacklist_screen.dart
// W4-batch-3b — BlackList management (Hybrid BlackListScreen parity): a searchable two-list
// screen — blacklisted customers (remove) and all customers (blacklist). Backed by the
// customer isBlackListed flag; the backend enforces it on the SMS-sale path (D-W4-4).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../shared/models/customer_model.dart';
import '../providers/customer_provider.dart';

class BlackListScreen extends ConsumerStatefulWidget {
  const BlackListScreen({super.key});

  @override
  ConsumerState<BlackListScreen> createState() => _BlackListScreenState();
}

class _BlackListScreenState extends ConsumerState<BlackListScreen> {
  static const _green = Color(0xFF00C853);
  String _query = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(customerProvider.notifier).loadCustomers());
  }

  bool _match(Customer c) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.name.toLowerCase().contains(q) || c.phone.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerProvider);
    final blacklisted = state.blacklistedCustomers.where(_match).toList();
    final active = state.activeCustomers.where(_match).toList();
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBar(
          title: 'Blacklisted Customers', showBackButton: true),
      body: state.isLoading && state.customers.isEmpty
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search by phone number or name',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle('Blacklisted'),
                if (blacklisted.isEmpty)
                  _note('You have not blacklisted any customer')
                else
                  ...blacklisted.map((c) => _row(c, blacklisted: true)),
                const SizedBox(height: 20),
                _sectionTitle('All customers'),
                if (active.isEmpty)
                  _note('No customers to show')
                else
                  ...active.map((c) => _row(c, blacklisted: false)),
              ],
            ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(t,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      );

  Widget _note(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text(t, style: const TextStyle(color: Colors.black54)),
      );

  Widget _row(Customer c, {required bool blacklisted}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(blacklisted ? Icons.block : Icons.person_outline,
            color: blacklisted ? Colors.red : _green),
        title: Text(c.name.isEmpty ? c.phone : c.name),
        subtitle: Text(c.phone),
        trailing: blacklisted
            ? TextButton(
                onPressed: () => _unblacklist(c), child: const Text('Remove'))
            : TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
                onPressed: () => _blacklist(c),
                child: const Text('Blacklist')),
      ),
    );
  }

  Future<void> _blacklist(Customer c) async {
    final r = await ref.read(customerProvider.notifier).blacklistCustomer(c.id);
    if (r != null) _toast('${_label(c)} blacklisted');
  }

  Future<void> _unblacklist(Customer c) async {
    final r =
        await ref.read(customerProvider.notifier).unblacklistCustomer(c.id);
    if (r != null) _toast('${_label(c)} removed from blacklist');
  }

  String _label(Customer c) => c.name.isEmpty ? c.phone : c.name;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: _green));
  }
}
