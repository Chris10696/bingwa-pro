import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/utils/formatters.dart';

// SiteLink Offer Model
class SiteLinkOffer {
  final String id;
  final String name;
  final String value;
  final double price;
  final String ussdCode;
  final String simCard;
  final bool isActive;

  SiteLinkOffer({
    required this.id,
    required this.name,
    required this.value,
    required this.price,
    required this.ussdCode,
    required this.simCard,
    this.isActive = true,
  });
}

// Mock data for SiteLink offers
final List<SiteLinkOffer> mockOffers = [
  SiteLinkOffer(
    id: '1',
    name: '1.5 GB - 3 Hrs',
    value: '1.5GB',
    price: 50,
    ussdCode: '*180*5*2*BH*1*1#',
    simCard: 'OPPO CPH2641 (BHC-GCLKL)',
    isActive: true,
  ),
  SiteLinkOffer(
    id: '2',
    name: '350 MBS - 7 Days',
    value: '350MB',
    price: 47,
    ussdCode: '*180*5*2*BH*2*1#',
    simCard: 'OPPO CPH2641 (BHC-GCLKL)',
    isActive: true,
  ),
  SiteLinkOffer(
    id: '3',
    name: '1GB - 1Hr',
    value: '1GB',
    price: 19,
    ussdCode: '*180*5*2*BH*5*1#',
    simCard: 'OPPO CPH2641 (BHC-GCLKL)',
    isActive: true,
  ),
  SiteLinkOffer(
    id: '4',
    name: '250MBS - 24 Hrs',
    value: '250MB',
    price: 20,
    ussdCode: '*180*5*2*BH*6*1#',
    simCard: 'OPPO CPH2641 (BHC-GCLKL)',
    isActive: true,
  ),
];

class SiteLinkScreen extends ConsumerStatefulWidget {
  const SiteLinkScreen({super.key});

  @override
  ConsumerState<SiteLinkScreen> createState() => _SiteLinkScreenState();
}

class _SiteLinkScreenState extends ConsumerState<SiteLinkScreen> {
  bool _isLinkActive = true;
  final String _webstoreLink = 'https://bingwahybrid.com/Crispinbuyonline';
  final String _agentName = 'Crispinonlinepurchase';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'SiteLink',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your SiteLink',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _agentName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _webstoreLink,
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: _copyToClipboard,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Activate SiteLink',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Switch(
                          value: _isLinkActive,
                          onChanged: (value) {
                            setState(() {
                              _isLinkActive = value;
                            });
                            _showStatusMessage(
                              value ? 'SiteLink activated' : 'SiteLink deactivated',
                            );
                          },
                          activeColor: const Color(0xFF00C853),
                        ),
                      ],
                    ),
                    if (!_isLinkActive)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Your SiteLink is currently inactive. Toggle to activate and share with customers.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Share Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Share Your SiteLink',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildShareButton(
                          icon: Icons.share,
                          label: 'Share Link',
                          color: Colors.blue,
                          onTap: _shareLink,
                        ),
                        _buildShareButton(
                          icon: Icons.qr_code,
                          label: 'QR Code',
                          color: Colors.purple,
                          onTap: _showQRCode,
                        ),
                        _buildShareButton(
                          icon: Icons.message,
                          label: 'SMS',
                          color: Colors.green,
                          onTap: _shareViaSms,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SiteLink Offers Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SiteLink Offers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddOfferDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Offers'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00C853),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Offers List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: mockOffers.length,
              itemBuilder: (context, index) {
                final offer = mockOffers[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Price: ${Formatters.formatCurrency(offer.price)}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                Checkbox(
                                  value: offer.isActive,
                                  onChanged: (value) {
                                    _toggleOfferStatus(offer.id);
                                  },
                                  activeColor: const Color(0xFF00C853),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _editOffer(offer),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
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
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16),
                                onPressed: () => _copyUssdCode(offer.ussdCode),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'SIM: ${offer.simCard}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard() {
    // Copy to clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _isLinkActive ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareLink() async {
    final url = Uri.parse(_webstoreLink);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SiteLink QR Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'QR Code\n(Placeholder)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(_webstoreLink),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _shareViaSms() async {
    final sms = Uri(
      scheme: 'sms',
      path: '', // Add phone number if needed
      queryParameters: {'body': _webstoreLink},
    );
    if (await canLaunchUrl(sms)) {
      await launchUrl(sms);
    }
  }

  void _showAddOfferDialog() {
    // Show dialog to add new offer
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add offer feature coming soon'),
      ),
    );
  }

  void _toggleOfferStatus(String offerId) {
    // Toggle offer active status
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Toggled offer $offerId'),
      ),
    );
  }

  void _editOffer(SiteLinkOffer offer) {
    // Edit offer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit offer ${offer.id} coming soon'),
      ),
    );
  }

  void _copyUssdCode(String ussdCode) {
    // Copy USSD code to clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('USSD code copied to clipboard'),
        backgroundColor: Colors.green,
      ),
    );
  }
}