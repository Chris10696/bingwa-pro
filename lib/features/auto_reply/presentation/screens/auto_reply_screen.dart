// lib/features/auto_reply/presentation/screens/auto_reply_screen.dart
// W4-batch-5 — Auto-Reply Messages (Hybrid AutoReplyScreen parity). Lists the six fixed
// auto-reply types from the on-device store (AutoReplyTemplates / SharedPreferences, seeded
// in W3), with a per-type active toggle; tapping edit opens EditAutoReplyScreen. No "add" —
// the set of outcomes is fixed (SUCCESS/FAILED/OFFER_UNAVAILABLE/ALREADY_RECOMMENDED/
// APP_PAUSED/CUSTOMER_BLOCKED).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/services/session_bridge_service.dart';
import 'edit_auto_reply_screen.dart';

/// Hybrid AutoReplyType → display title.
const Map<String, String> kAutoReplyTitles = {
  'SUCCESS': 'Successful Transaction',
  'FAILED': 'Failed Transaction',
  'OFFER_UNAVAILABLE': 'Offer Unavailable',
  'ALREADY_RECOMMENDED': 'Already Recommended',
  'APP_PAUSED': 'App Paused',
  'CUSTOMER_BLOCKED': 'Blacklisted Customer',
};

class AutoReplyTemplate {
  final String type;
  final String message;
  final bool isActive;
  const AutoReplyTemplate({
    required this.type,
    required this.message,
    required this.isActive,
  });
  String get title => kAutoReplyTitles[type] ?? type;
}

class AutoReplyScreen extends ConsumerStatefulWidget {
  const AutoReplyScreen({super.key});

  @override
  ConsumerState<AutoReplyScreen> createState() => _AutoReplyScreenState();
}

class _AutoReplyScreenState extends ConsumerState<AutoReplyScreen> {
  static const _green = Color(0xFF00C853);
  bool _loading = true;
  List<AutoReplyTemplate> _templates = [];

  SessionBridgeService get _bridge => ref.read(sessionBridgeServiceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final raw = await _bridge.getAutoReplies();
    if (!mounted) return;
    setState(() {
      _templates = raw
          .map((m) => AutoReplyTemplate(
                type: m['type'] as String? ?? '',
                message: m['message'] as String? ?? '',
                isActive: m['isActive'] as bool? ?? true,
              ))
          .toList();
      _loading = false;
    });
  }

  Future<void> _toggleActive(AutoReplyTemplate t, bool active) async {
    await _bridge.saveAutoReply(
        type: t.type, message: t.message, isActive: active);
    await _load();
  }

  Future<void> _edit(AutoReplyTemplate t) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditAutoReplyScreen(template: t)),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar:
          const CustomAppBar(title: 'Auto-Reply Messages', showBackButton: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _templates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = _templates[i];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(t.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ),
                            Switch(
                              value: t.isActive,
                              activeThumbColor: _green,
                              onChanged: (v) => _toggleActive(t, v),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  size: 20, color: _green),
                              tooltip: 'Edit',
                              onPressed: () => _edit(t),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.message,
                          style: TextStyle(
                              color: Colors.grey[800],
                              height: 1.4,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
