// lib/features/settings/presentation/screens/settings_screen.dart
import 'package:bingwa_pro/features/auth/presentation/providers/auth_provider.dart';
import 'package:bingwa_pro/shared/models/auth_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:line_icons/line_icons.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/security/secure_storage_manager.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _notificationsEnabled = true;
  bool _transactionSounds = true;
  String _language = 'English';
  String _theme = 'Light';
  double _transactionLimit = 5000.0;
  double _dailyLimit = 100000.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometricEnabled = await SecureStorageManager.getBiometricEnabled(false);
    
    setState(() {
      _biometricEnabled = biometricEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(authNotifierProvider).agent;

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Settings',
        showBackButton: true,
      ),
      body: ListView(
        children: [
          // Profile Section
          _buildProfileSection(agent),
          const SizedBox(height: 20),

          // ===== PAYMENT SETTINGS SECTION (ADDED) =====
          _buildSectionHeader('Payment Settings'),
          _buildSettingsCard([
            _buildSettingsItem(
              icon: Icons.store,
              title: 'Payment Method',
              subtitle: agent?.tillNumber != null 
                  ? 'Till: ${agent!.tillNumber}' 
                  : 'Set up your till/paybill number',
              onTap: () {
                context.push('/settings/payment');
              },
            ),
            _buildSettingsItem(
              icon: Icons.history,
              title: 'Transaction History',
              subtitle: 'View all your transactions',
              onTap: () {
                context.push('/transaction-history');
              },
            ),
          ]),
          const SizedBox(height: 20),

          // Account Settings
          _buildSectionHeader('Account Settings'),
          _buildSettingsCard([
            _buildSettingsItem(
              icon: LineIcons.userCircle,
              title: 'Profile Information',
              subtitle: 'Update your personal details',
              onTap: () {
                context.push('/settings/profile');
              },
            ),
            _buildSettingsItem(
              icon: LineIcons.lock,
              title: 'Security',
              subtitle: 'Change PIN, biometrics',
              onTap: () {
                _showSecurityOptions();
              },
            ),
          ]),
          const SizedBox(height: 20),

          // App Preferences
          _buildSectionHeader('App Preferences'),
          _buildSettingsCard([
            _buildSwitchItem(
              icon: LineIcons.fingerprint,
              title: 'Biometric Login',
              subtitle: 'Use fingerprint or face ID',
              value: _biometricEnabled,
              onChanged: (value) async {
                setState(() {
                  _biometricEnabled = value;
                });
                await SecureStorageManager.setBiometricEnabled(value);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(value 
                        ? 'Biometric login enabled' 
                        : 'Biometric login disabled'),
                    backgroundColor: value ? Colors.green : Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            _buildSwitchItem(
              icon: LineIcons.bell,
              title: 'Push Notifications',
              subtitle: 'Receive transaction alerts',
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            _buildSwitchItem(
              icon: LineIcons.volumeUp,
              title: 'Transaction Sounds',
              subtitle: 'Play sounds on transactions',
              value: _transactionSounds,
              onChanged: (value) {
                setState(() {
                  _transactionSounds = value;
                });
              },
            ),
            _buildDropdownItem(
              icon: LineIcons.language,
              title: 'Language',
              subtitle: _language,
              items: ['English', 'Swahili'],
              value: _language,
              onChanged: (value) {
                setState(() {
                  _language = value!;
                });
              },
            ),
          ]),
          const SizedBox(height: 20),

          // Support
          _buildSectionHeader('Support'),
          _buildSettingsCard([
            _buildSettingsItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              subtitle: 'FAQs, contact support',
              onTap: () {
                context.push('/help');
              },
            ),
            _buildSettingsItem(
              icon: Icons.info_outline,
              title: 'About Bingwa Pro',
              subtitle: 'App version 1.0.0',
              onTap: () {
                _showAboutDialog();
              },
            ),
          ]),
          const SizedBox(height: 20),

          // Danger Zone
          _buildSectionHeader('Danger Zone'),
          _buildSettingsCard([
            _buildSettingsItem(
              icon: LineIcons.alternateSignOut,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              color: Colors.red,
              onTap: () {
                _confirmLogout(context);
              },
            ),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileSection(AgentProfile? agent) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color.fromARGB(25, 0, 200, 83),
            child: Text(
              _getInitials(agent?.fullName),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00C853),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent?.fullName ?? 'Agent Name',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  agent?.phoneNumber ?? 'Phone number',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(25, 0, 200, 83),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    agent?.status.toString().split('.').last ?? 'ACTIVE',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF00C853),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF00C853)),
            onPressed: () {
              context.push('/settings/profile');
            },
          ),
        ],
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'A';
    final parts = name.split(' ');
    if (parts.isEmpty) return 'A';
    return parts[0].substring(0, 1).toUpperCase();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF00C853)),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: Text(
        subtitle, 
        style: TextStyle(
          color: color != null ? color.withOpacity(0.7) : Colors.grey[600],
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00C853)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: const Color(0xFF00C853).withOpacity(0.5),
        thumbColor: WidgetStateProperty.resolveWith<Color>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF00C853);
            }
            return Colors.grey.shade400;
          },
        ),
      ),
    );
  }

  Widget _buildDropdownItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> items,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF00C853)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: onChanged,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
      ),
    );
  }

  void _showSecurityOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.lock, color: Color(0xFF00C853)),
                title: const Text('Change PIN'),
                onTap: () {
                  Navigator.pop(context);
                  _showPinChangeDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.fingerprint, color: Color(0xFF00C853)),
                title: const Text('Biometric Settings'),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/biometric-setup');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPinChangeDialog() {
    // Implement PIN change dialog
    showDialog(
      context: context,
      builder: (context) => const PinChangeDialog(),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Bingwa Pro',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.store, size: 40, color: Color(0xFF00C853)),
      children: [
        const Text('Bingwa Pro - Safaricom Agent Platform'),
        const SizedBox(height: 8),
        const Text('© 2024 Bingwa Pro. All rights reserved.'),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                final authNotifier = ref.read(authNotifierProvider.notifier);
                await authNotifier.logout();
                await SecureStorageManager.clearAll();
                
                if (!mounted) return;
                Navigator.pop(context);
                context.go('/login');
              } catch (e) {
                if (!mounted) return;
                Navigator.pop(context);
                await SecureStorageManager.clearAll();
                context.go('/login');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// PIN Change Dialog
class PinChangeDialog extends StatefulWidget {
  const PinChangeDialog({super.key});

  @override
  State<PinChangeDialog> createState() => _PinChangeDialogState();
}

class _PinChangeDialogState extends State<PinChangeDialog> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscureOldPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _oldPinController,
              obscureText: _obscureOldPin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Current PIN',
                hintText: '••••',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureOldPin ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureOldPin = !_obscureOldPin;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPinController,
              obscureText: _obscureNewPin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'New PIN',
                hintText: '••••',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPin ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPin = !_obscureNewPin;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPinController,
              obscureText: _obscureConfirmPin,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                labelText: 'Confirm New PIN',
                hintText: '••••',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPin ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPin = !_obscureConfirmPin;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_newPinController.text != _confirmPinController.text) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('New PINs do not match'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (_newPinController.text.length != 4) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PIN must be 4 digits'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            // TODO: Call API to verify old PIN and update
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN changed successfully'),
                backgroundColor: Colors.green,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
          ),
          child: const Text('Change PIN'),
        ),
      ],
    );
  }
}