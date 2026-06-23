// lib/features/auto_renewals/presentation/screens/auto_renewals_screen.dart
// W2.4D: rebuilt against real scheduled-transaction endpoints (D-W2-5).
// Replaces the entire W1 mock-data implementation. A renewal is a SCHEDULED
// transaction; rescheduleInfo carries {scheduledFor, isRecurring,
// daysRemaining}. Offers come from offersNotifier (4B). W2 persists the
// schedule; W3's pipeline executes due rows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/offer_model.dart';
import '../../../../shared/models/transaction_model.dart';
import '../../../offers/presentation/providers/offer_provider.dart';
import '../providers/auto_renewals_provider.dart';

class AutoRenewalsScreen extends ConsumerStatefulWidget {
  const AutoRenewalsScreen({super.key});
  @override
  ConsumerState<AutoRenewalsScreen> createState() =>
      _AutoRenewalsScreenState();
}

class _AutoRenewalsScreenState extends ConsumerState<AutoRenewalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(autoRenewalsNotifierProvider.notifier).loadRenewals();
      ref.read(offersNotifierProvider.notifier).loadOffers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(autoRenewalsNotifierProvider);
    final notifier = ref.read(autoRenewalsNotifierProvider.notifier);

    ref.listen<AutoRenewalsState>(autoRenewalsNotifierProvider, (prev, next) {
      if (next.errorMessage != null &&
          prev?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        notifier.clearError();
      }
    });

    return Scaffold(
      appBar: const CustomAppBar(title: 'Auto Renewals', showBackButton: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showScheduleSheet(),
        backgroundColor: const Color(0xFF00C853),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: state.isLoading && state.renewals.isEmpty
          ? const LoadingIndicator(message: 'Loading auto renewals...')
          : state.renewals.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () => notifier.loadRenewals(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.renewals.length,
                    itemBuilder: (context, i) =>
                        _buildRenewalCard(state.renewals[i], notifier),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.autorenew, size: 72, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No auto renewals',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Tap + to schedule an offer for a customer',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRenewalCard(
    ScheduledTransaction renewal,
    AutoRenewalsNotifier notifier,
  ) {
    final info = renewal.rescheduleInfo ?? const {};
    final scheduledForRaw = info['scheduledFor']?.toString();
    final scheduledFor =
        scheduledForRaw != null ? DateTime.tryParse(scheduledForRaw) : null;
    final isRecurring = info['isRecurring'] == true;
    final daysRemaining = info['daysRemaining'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    renewal.offerName ?? 'Offer',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF00C853),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isRecurring ? Colors.blue : Colors.orange)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isRecurring ? 'Recurring' : 'One-time',
                    style: TextStyle(
                      color: isRecurring ? Colors.blue : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow(Icons.person_outline, renewal.customerPhone),
            const SizedBox(height: 6),
            _infoRow(Icons.attach_money,
                Formatters.formatCurrency(renewal.amount)),
            if (scheduledFor != null) ...[
              const SizedBox(height: 6),
              _infoRow(
                Icons.schedule,
                'Next: ${DateFormat('dd MMM yyyy, HH:mm').format(scheduledFor.toLocal())}',
              ),
            ],
            if (isRecurring && daysRemaining != null) ...[
              const SizedBox(height: 6),
              _infoRow(Icons.repeat, 'Renews daily for $daysRemaining day(s)'),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmCancel(renewal, notifier),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  void _confirmCancel(
    ScheduledTransaction renewal,
    AutoRenewalsNotifier notifier,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Cancel Renewal'),
        content: Text(
          'Cancel the scheduled renewal for ${renewal.customerPhone}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogCtx);
              notifier.cancel(renewal.id);
            },
            child: const Text('Cancel Renewal'),
          ),
        ],
      ),
    );
  }

  // ── Schedule sheet (Hybrid "Reschedule Offer") ──────────────────────────────
  void _showScheduleSheet() {
    final offersState = ref.read(offersNotifierProvider);
    final activeOffers =
        offersState.offers.where((o) => o.isActive).toList();

    if (activeOffers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create or activate an offer first'),
        ),
      );
      return;
    }

    final phoneController = TextEditingController();
    Offer selectedOffer = activeOffers.first;
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();
    bool autoRenew = false;
    final daysController = TextEditingController(text: '7');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(
                        child: Text(
                          'Reschedule Offer',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Customer Phone',
                          hintText: '07XX XXX XXX',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().length < 9)
                            ? 'Enter a valid phone number'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Offer>(
                        initialValue: selectedOffer,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Offer',
                          border: OutlineInputBorder(),
                        ),
                        items: activeOffers
                            .map((o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(
                                    '${o.name} — KES ${o.price}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (o) {
                          if (o != null) setLocal(() => selectedOffer = o);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 18),
                              label: Text(
                                DateFormat('dd MMM yyyy').format(selectedDate),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setLocal(() => selectedDate = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time, size: 18),
                              label: Text(selectedTime.format(ctx)),
                              onPressed: () async {
                                final picked = await showTimePicker(
                                  context: ctx,
                                  initialTime: selectedTime,
                                );
                                if (picked != null) {
                                  setLocal(() => selectedTime = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: const Color(0xFF00C853),
                        title: const Text('Auto-Renew'),
                        value: autoRenew,
                        onChanged: (v) =>
                            setLocal(() => autoRenew = v ?? false),
                      ),
                      if (autoRenew)
                        TextFormField(
                          controller: daysController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Renew daily for next N Day(s)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (!autoRenew) return null;
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 1) return 'Enter valid days';
                            return null;
                          },
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                          ),
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            final scheduledFor = DateTime(
                              selectedDate.year,
                              selectedDate.month,
                              selectedDate.day,
                              selectedTime.hour,
                              selectedTime.minute,
                            );
                            Navigator.pop(sheetCtx);
                            await ref
                                .read(autoRenewalsNotifierProvider.notifier)
                                .schedule(
                                  offerId: selectedOffer.id,
                                  customerPhone: phoneController.text.trim(),
                                  scheduledFor: scheduledFor,
                                  isRecurring: autoRenew,
                                  daysToRecur: autoRenew
                                      ? int.tryParse(
                                          daysController.text.trim())
                                      : null,
                                );
                          },
                          child: const Text(
                            'Schedule',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}