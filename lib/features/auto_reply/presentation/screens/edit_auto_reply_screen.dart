// lib/features/auto_reply/presentation/screens/edit_auto_reply_screen.dart
// W4-batch-5 — Edit AutoReply (Hybrid EditAutoReplyMessageScreen parity): edit the message,
// insert placeholder tokens, toggle active, and see a live preview. Saves to the on-device
// template store via the session bridge (returns true to the list on save).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/services/session_bridge_service.dart';
import 'auto_reply_screen.dart';

// Hybrid AutoReplyPlaceHolder set (verbatim tokens + human descriptions).
const List<({String token, String desc})> kAutoReplyPlaceholders = [
  (token: '<firstName>', desc: "Customer's first name"),
  (token: '<surname>', desc: "Customer's surname"),
  (token: '<amount>', desc: 'Amount paid'),
  (token: '<mpesaCode>', desc: 'M-Pesa transaction code'),
  (token: '<offerName>', desc: 'Offer name'),
  (token: '<offerPrice>', desc: 'Offer price'),
];

class EditAutoReplyScreen extends ConsumerStatefulWidget {
  final AutoReplyTemplate template;
  const EditAutoReplyScreen({super.key, required this.template});

  @override
  ConsumerState<EditAutoReplyScreen> createState() =>
      _EditAutoReplyScreenState();
}

class _EditAutoReplyScreenState extends ConsumerState<EditAutoReplyScreen> {
  static const _green = Color(0xFF00C853);
  late final TextEditingController _controller;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.template.message);
    _active = widget.template.isActive;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insert(String token) {
    final sel = _controller.selection;
    final text = _controller.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final newText = text.replaceRange(start, end, token);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    setState(() {});
  }

  String _preview() => _controller.text
      .replaceAll('<firstName>', 'John')
      .replaceAll('<surname>', 'Doe')
      .replaceAll('<amount>', '100')
      .replaceAll('<mpesaCode>', 'TXN12345')
      .replaceAll('<offerName>', '250MB Daily')
      .replaceAll('<offerPrice>', '20');

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(sessionBridgeServiceProvider).saveAutoReply(
          type: widget.template.type,
          message: _controller.text.trim(),
          isActive: _active,
        );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: const CustomAppBar(title: 'Edit AutoReply', showBackButton: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.template.title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Message',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          const Text('Insert placeholder',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kAutoReplyPlaceholders
                .map((p) => ActionChip(
                      label: Text(p.token),
                      tooltip: p.desc,
                      onPressed: () => _insert(p.token),
                      backgroundColor: const Color(0x1A00C853),
                      labelStyle: const TextStyle(color: _green),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Active', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('Send this reply when the matching outcome occurs',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Switch(
                value: _active,
                activeThumbColor: _green,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Preview', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(_preview(), style: const TextStyle(height: 1.4)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
