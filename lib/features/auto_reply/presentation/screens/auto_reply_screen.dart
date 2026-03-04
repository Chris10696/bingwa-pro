import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';

// AutoReply Message Model
class AutoReplyMessage {
  final String id;
  final String trigger;
  final String message;
  final bool isActive;
  final bool useCustomerName;

  AutoReplyMessage({
    required this.id,
    required this.trigger,
    required this.message,
    required this.isActive,
    required this.useCustomerName,
  });
}

// Mock data for auto-reply messages
final List<AutoReplyMessage> mockMessages = [
  AutoReplyMessage(
    id: '1',
    trigger: 'Successful Response',
    message: 'Hi <firstname>, Thank you for purchasing from Bingwa Hybrid',
    isActive: true,
    useCustomerName: true,
  ),
  AutoReplyMessage(
    id: '2',
    trigger: 'Offer Already Recommended',
    message: 'Hello <firstname>, you have already purchased this offer today. Please try again tomorrow',
    isActive: true,
    useCustomerName: true,
  ),
  AutoReplyMessage(
    id: '3',
    trigger: 'Failed Request',
    message: 'Hello <firstname>, Your request failed. Please hold as we look into the issue',
    isActive: true,
    useCustomerName: true,
  ),
  AutoReplyMessage(
    id: '4',
    trigger: 'Unavailable Offer',
    message: 'Hi <firstname>, there is no offer matching the amount you have paid. Please pay the correct amount then try again',
    isActive: true,
    useCustomerName: true,
  ),
  AutoReplyMessage(
    id: '5',
    trigger: 'App Paused',
    message: 'Hi <firstname>, there is an issue affecting our systems. You will however get your offer as soon as they become operational',
    isActive: true,
    useCustomerName: true,
  ),
  AutoReplyMessage(
    id: '6',
    trigger: 'Customer Blacklisted',
    message: 'Hi <firstname>, there is an issue affecting your account. Please reach out to us for assistance',
    isActive: true,
    useCustomerName: true,
  ),
];

class AutoReplyScreen extends ConsumerStatefulWidget {
  const AutoReplyScreen({super.key});

  @override
  ConsumerState<AutoReplyScreen> createState() => _AutoReplyScreenState();
}

class _AutoReplyScreenState extends ConsumerState<AutoReplyScreen> {
  String _searchQuery = '';
  String? _editingMessageId;

  @override
  Widget build(BuildContext context) {
    final filteredMessages = _searchQuery.isEmpty
        ? mockMessages
        : mockMessages
            .where((msg) =>
                msg.trigger.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                msg.message.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Auto-Reply Messages',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search messages...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredMessages.length,
              itemBuilder: (context, index) {
                final message = filteredMessages[index];
                final isEditing = _editingMessageId == message.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                message.trigger,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Switch(
                                  value: message.isActive,
                                  onChanged: (value) {
                                    _toggleMessageStatus(message.id);
                                  },
                                  activeColor: const Color(0xFF00C853),
                                ),
                                IconButton(
                                  icon: Icon(
                                    isEditing ? Icons.close : Icons.edit,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _editingMessageId =
                                          isEditing ? null : message.id;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),

                        if (!isEditing) ...[
                          const SizedBox(height: 8),
                          // Message Preview
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              message.message,
                              style: TextStyle(
                                color: Colors.grey[800],
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Placeholder info
                          if (message.useCustomerName)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '<firstname> will be replaced with customer\'s first name',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ] else
                          _buildEditForm(message),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMessageDialog,
        backgroundColor: const Color(0xFF00C853),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEditForm(AutoReplyMessage message) {
    final TextEditingController triggerController =
        TextEditingController(text: message.trigger);
    final TextEditingController messageController =
        TextEditingController(text: message.message);
    bool useCustomerName = message.useCustomerName;

    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: triggerController,
              decoration: const InputDecoration(
                labelText: 'Trigger',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                hintText: 'Enter message...',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: useCustomerName,
                  onChanged: (value) {
                    setState(() {
                      useCustomerName = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF00C853),
                ),
                const Text('Include customer name (<firstname>)'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _editingMessageId = null;
                    });
                  },
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _saveMessage(
                      message.id,
                      triggerController.text,
                      messageController.text,
                      useCustomerName,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _toggleMessageStatus(String id) {
    // Toggle message active status
    setState(() {
      final index = mockMessages.indexWhere((m) => m.id == id);
      if (index != -1) {
        final updated = mockMessages[index];
        mockMessages[index] = AutoReplyMessage(
          id: updated.id,
          trigger: updated.trigger,
          message: updated.message,
          isActive: !updated.isActive,
          useCustomerName: updated.useCustomerName,
        );
      }
    });
  }

  void _saveMessage(
    String id,
    String trigger,
    String message,
    bool useCustomerName,
  ) {
    // Save edited message
    setState(() {
      final index = mockMessages.indexWhere((m) => m.id == id);
      if (index != -1) {
        mockMessages[index] = AutoReplyMessage(
          id: id,
          trigger: trigger,
          message: message,
          isActive: mockMessages[index].isActive,
          useCustomerName: useCustomerName,
        );
      }
      _editingMessageId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showAddMessageDialog() {
    // Show dialog to add new message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add message feature coming soon'),
      ),
    );
  }
}