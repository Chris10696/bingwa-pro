// lib/features/quick_dial/presentation/screens/quick_dial_screen.dart
// W1: converted to placeholder per Q12.
// Prior implementation referenced deleted types (ProductBundle, TransactionType.airtime)
// and deleted repository methods (executeAirtime/Data/Sms). Real Quick Dial UI
// is W2 territory; placeholder keeps the route functional and the import in
// app_router.dart unbroken.
//
// Hardcoded USSD codes from the previous mockProducts are preserved as backend
// seed data in offers.seed.ts (verified Hybrid Image 2 codes).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/custom_app_bar.dart';

class QuickDialScreen extends ConsumerWidget {
  const QuickDialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Quick Dial',
        showBackButton: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.speed,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Quick Dial Coming Soon',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Manual repurchase for customers ships in Wave 2',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}