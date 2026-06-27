// lib/features/authorized_senders/presentation/screens/authorized_senders_screen.dart
//
// W4-batch-2 — Authorized Senders management (Hybrid AuthorizedSendersScreen parity).
//
// The list is an on-device allowlist (SessionBridge prefs, D-W4-2) that EXTENDS the built-in
// M-Pesa sender fence in MpesaMessageListener — payment SMS from any sender here are processed
// in addition to MPESA/40400/40401. There is no backend involved (the receiver must consult it
// offline at SMS-arrival time). Built-in senders are always allowed and are not shown here.
//
// Labels + flow mirror Hybrid: empty state "No authorized senders yet" / "Add senders using the
// + button"; FAB(+) → add dialog (numeric); validation "Phone number cannot be empty" /
// "This sender is already authorized"; toasts "Sender added/removed successfully".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/session_bridge_service.dart';

class AuthorizedSendersScreen extends ConsumerStatefulWidget {
  const AuthorizedSendersScreen({super.key});

  @override
  ConsumerState<AuthorizedSendersScreen> createState() =>
      _AuthorizedSendersScreenState();
}

class _AuthorizedSendersScreenState
    extends ConsumerState<AuthorizedSendersScreen> {
  static const _green = Color(0xFF00C853);

  bool _loading = true;
  List<String> _senders = [];

  SessionBridgeService get _bridge => ref.read(sessionBridgeServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _bridge.getAuthorizedSenders();
    if (!mounted) return;
    setState(() {
      _senders = list..sort();
      _loading = false;
    });
  }

  void _toast(String msg, {Color? bg}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: bg),
    );
  }

  Future<void> _add() async {
    final controller = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Sender'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          maxLength: 12,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: 'e.g. 0712345678',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (input == null) return; // cancelled
    if (input.isEmpty) {
      _toast('Phone number cannot be empty', bg: Colors.red);
      return;
    }
    if (_senders.contains(input)) {
      _toast('This sender is already authorized', bg: Colors.orange);
      return;
    }
    final added = await _bridge.addAuthorizedSender(input);
    if (added) {
      _toast('Sender added successfully', bg: _green);
      await _load();
    } else {
      _toast('This sender is already authorized', bg: Colors.orange);
    }
  }

  Future<void> _remove(String sender) async {
    await _bridge.removeAuthorizedSender(sender);
    _toast('Sender removed successfully', bg: _green);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Authorized Senders'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        onPressed: _add,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _senders.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _senders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final s = _senders[i];
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const Icon(Icons.verified_user_outlined,
                            color: _green),
                        title: Text(s),
                        subtitle: const Text(
                            'Messages from this sender will be processed'),
                        trailing: IconButton(
                          icon:
                              const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Remove',
                          onPressed: () => _remove(s),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No authorized senders yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Add senders using the + button',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
