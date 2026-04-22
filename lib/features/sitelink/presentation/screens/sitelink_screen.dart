// lib/features/sitelink/presentation/screens/sitelink_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class SiteLinkOffer {
  final String id;
  final String name;
  final String value;
  final double price;
  final String ussdCode;
  bool isActive;

  SiteLinkOffer({
    required this.id,
    required this.name,
    required this.value,
    required this.price,
    required this.ussdCode,
    this.isActive = true,
  });
}

class SiteLinkScreen extends ConsumerStatefulWidget {
  const SiteLinkScreen({super.key});

  @override
  ConsumerState<SiteLinkScreen> createState() => _SiteLinkScreenState();
}

class _SiteLinkScreenState extends ConsumerState<SiteLinkScreen> {
  bool _isLinkActive = true;

  // Offers list – agents can toggle/edit these
  final List<SiteLinkOffer> _offers = [
    SiteLinkOffer(id: '1', name: '1.5 GB – 3 Hours',      value: '1.5GB',  price: 50, ussdCode: '*180*5*2*@*1*1#'),
    SiteLinkOffer(id: '2', name: '350 MB – 7 Days',        value: '350MB',  price: 47, ussdCode: '*180*5*2*@*2*1#'),
    SiteLinkOffer(id: '3', name: '1 GB – 1 Hour',          value: '1GB',    price: 19, ussdCode: '*180*5*2*@*5*1#'),
    SiteLinkOffer(id: '4', name: '250 MB – 24 Hours',      value: '250MB',  price: 20, ussdCode: '*180*5*2*@*6*1#'),
    SiteLinkOffer(id: '5', name: '1 GB – 24 Hours',        value: '1GB/24', price: 99, ussdCode: '*180*5*2*@*7*1#'),
    SiteLinkOffer(id: '6', name: '1.25 GB – Until Midnight', value: '1.25GB', price: 55, ussdCode: '*180*5*2*@*8*1#'),
  ];

  // ── URL helpers ─────────────────────────────────────────────────────────────

  /// Converts a name like "Chris Kinyua" or "Kinyua Data" → "ChrisKinyua"
  String _slugify(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

  String _buildUrl(String agentName) =>
      'https://bingwahybrid.com/${_slugify(agentName)}';

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final agent = ref.watch(authNotifierProvider).agent;

    // Use business name if set, otherwise full name, otherwise fallback
    final displayName =
        (agent?.businessName?.isNotEmpty == true)
            ? agent!.businessName!
            : (agent?.fullName.isNotEmpty == true)
                ? agent!.fullName
                : 'My Store';

    final siteUrl = _buildUrl(displayName);

    return Scaffold(
      appBar: const CustomAppBar(title: 'SiteLink', showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(displayName, siteUrl),
            const SizedBox(height: 20),
            _buildShareCard(siteUrl),
            const SizedBox(height: 20),
            _buildOffersSection(),
          ],
        ),
      ),
    );
  }

  // ── Header card ─────────────────────────────────────────────────────────────
  Widget _buildHeaderCard(String displayName, String siteUrl) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Agent identity banner
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00C853),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Your customer-facing store',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // URL display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your SiteLink URL',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          siteUrl,
                          style: const TextStyle(
                            color: Color(0xFF1565C0),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy,
                        size: 20, color: Color(0xFF00C853)),
                    tooltip: 'Copy link',
                    onPressed: () => _copyToClipboard(siteUrl),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Activate toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _isLinkActive ? Icons.link : Icons.link_off,
                      color: _isLinkActive
                          ? const Color(0xFF00C853)
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isLinkActive
                          ? 'SiteLink is Active'
                          : 'SiteLink is Inactive',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isLinkActive
                            ? const Color(0xFF00C853)
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                Switch(
                  value: _isLinkActive,
                  activeColor: const Color(0xFF00C853),
                  onChanged: (v) {
                    setState(() => _isLinkActive = v);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        v ? 'SiteLink activated' : 'SiteLink deactivated',
                      ),
                      backgroundColor:
                          v ? Colors.green : Colors.orange,
                      duration: const Duration(seconds: 2),
                    ));
                  },
                ),
              ],
            ),

            if (!_isLinkActive)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Toggle above to make your store visible to customers.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Share card ───────────────────────────────────────────────────────────────
  Widget _buildShareCard(String siteUrl) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share Your SiteLink',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareButton(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  color: Colors.teal,
                  onTap: () => _copyToClipboard(siteUrl),
                ),
                _buildShareButton(
                  icon: Icons.open_in_browser,
                  label: 'Open',
                  color: Colors.blue,
                  onTap: () => _openInBrowser(siteUrl),
                ),
                _buildShareButton(
                  icon: Icons.sms_outlined,
                  label: 'Send SMS',
                  color: Colors.green,
                  onTap: () => _shareViaSms(siteUrl),
                ),
                _buildShareButton(
                  icon: Icons.qr_code,
                  label: 'QR Code',
                  color: Colors.purple,
                  onTap: () => _showQrPlaceholder(siteUrl),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }

  // ── Offers section ───────────────────────────────────────────────────────────
  Widget _buildOffersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SiteLink Offers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showComingSoonSnackbar,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Manage'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00C853),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _offers.length,
          itemBuilder: (context, index) =>
              _buildOfferCard(_offers[index]),
        ),
      ],
    );
  }

  Widget _buildOfferCard(SiteLinkOffer offer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        offer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.formatCurrency(offer.price),
                        style: const TextStyle(
                          color: Color(0xFF00C853),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Transform.scale(
                      scale: 0.85,
                      child: Switch(
                        value: offer.isActive,
                        activeColor: const Color(0xFF00C853),
                        onChanged: (v) =>
                            setState(() => offer.isActive = v),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Colors.grey),
                      onPressed: _showComingSoonSnackbar,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      offer.ussdCode,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        _copyToClipboard(offer.ussdCode, label: 'USSD code'),
                    child: const Icon(Icons.copy, size: 15,
                        color: Color(0xFF00C853)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────
  void _copyToClipboard(String text, {String label = 'Link'}) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label copied to clipboard'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaSms(String url) async {
    final sms = Uri(
      scheme: 'sms',
      queryParameters: {'body': 'Buy mobile data here: $url'},
    );
    if (await canLaunchUrl(sms)) await launchUrl(sms);
  }

  void _showQrPlaceholder(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'QR Code\nGeneration\nComing Soon',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(url,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This feature is coming soon')),
    );
  }
}