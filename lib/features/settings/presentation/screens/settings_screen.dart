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
    // Load settings from secure storage or backend
    final biometricKey = await SecureStorageManager.getBiometricKey();
    setState(() {
      _biometricEnabled = biometricKey != null;
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

          // Account Settings
          _buildSectionHeader('Account Settings'),
          _buildSettingsCard([
            _buildSettingsItem(
              icon: LineIcons.userCircle,
              title: 'Profile Information',
              subtitle: 'Update your personal details',
              onTap: () {
                context.push('/profile');
              },
            ),
            _buildSettingsItem(
              icon: LineIcons.lock,
              title: 'Security',
              subtitle: 'Change PIN, biometrics',
              onTap: () {
                context.push('/security');
              },
            ),
            _buildSettingsItem(
              icon: LineIcons.wallet,
              title: 'Wallet Settings',
              subtitle: 'Payment methods, limits',
              onTap: () {
                context.push('/wallet-settings');
              },
            ),
          ]),

          // App Preferences
          _buildSectionHeader('App Preferences'),
          _buildSettingsCard([
            _buildSwitchItem(
              icon: LineIcons.fingerprint,
              title: 'Biometric Login',
              subtitle: 'Use fingerprint or face ID',
              value: _biometricEnabled,
              onChanged: (value) {
                setState(() {
                  _biometricEnabled = value;
                });
                // TODO: Save biometric setting
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
              items: ['English', 'Swahili', 'French'],
              value: _language,
              onChanged: (value) {
                setState(() {
                  _language = value!;
                });
              },
            ),
            _buildDropdownItem(
              icon: LineIcons.palette,
              title: 'Theme',
              subtitle: _theme,
              items: ['Light', 'Dark', 'Auto'],
              value: _theme,
              onChanged: (value) {
                setState(() {
                  _theme = value!;
                });
              },
            ),
          ]),

          // Transaction Limits
          _buildSectionHeader('Transaction Limits'),
          _buildSettingsCard([
            _buildSliderItem(
              title: 'Per Transaction Limit',
              subtitle: 'Maximum amount per transaction',
              value: _transactionLimit,
              min: 100,
              max: 50000,
              divisions: 49,
              onChanged: (value) {
                setState(() {
                  _transactionLimit = value;
                });
              },
            ),
            _buildSliderItem(
              title: 'Daily Limit',
              subtitle: 'Maximum total transactions per day',
              value: _dailyLimit,
              min: 1000,
              max: 500000,
              divisions: 49,
              onChanged: (value) {
                setState(() {
                  _dailyLimit = value;
                });
              },
            ),
          ]),

          // Support
          _buildSectionHeader('Support'),
          _buildSettingsCard([
            _buildSettingsItem(
              // Using Material Icons as reliable fallback
              icon: Icons.help_outline, // Material icon instead of LineIcons
              title: 'Help & Support',
              subtitle: 'FAQs, contact support',
              onTap: () {
                context.push('/help');
              },
            ),
            _buildSettingsItem(
              icon: LineIcons.fileAlt,
              title: 'Terms & Conditions',
              subtitle: 'App usage terms',
              onTap: () {
                context.push('/terms');
              },
            ),
            _buildSettingsItem(
              // Using Material Icons as reliable fallback
              icon: Icons.security, // Material icon instead of LineIcons
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              onTap: () {
                context.push('/privacy');
              },
            ),
            _buildSettingsItem(
              icon: LineIcons.infoCircle,
              title: 'About Bingwa Pro',
              subtitle: 'App version 1.0.0',
              onTap: () {
                context.push('/about');
              },
            ),
          ]),

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
            _buildSettingsItem(
              icon: LineIcons.trash,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              color: Colors.red,
              onTap: () {
                _confirmDeleteAccount(context);
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
            // Using withAlpha for better precision
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
            // Fixed: Using Color.fromARGB directly
            backgroundColor: const Color.fromARGB(25, 0, 200, 83),
            child: Text(
              // FIXED: Simplified null handling
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
                    (agent?.status as String?) ?? 'ACTIVE',
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
              context.push('/profile');
            },
          ),
        ],
      ),
    );
  }

  // Helper method to get initials
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
        thumbColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.selected)) {
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

  Widget _buildSliderItem({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: 'KES ${value.toStringAsFixed(0)}',
                  // FIXED: Correct parameter name is thumbColor, not activeThumbColor
                  thumbColor: const Color(0xFF00C853),
                  activeColor: const Color(0xFF00C853),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'KES ${value.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement logout
              context.go('/login');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement account deletion
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}