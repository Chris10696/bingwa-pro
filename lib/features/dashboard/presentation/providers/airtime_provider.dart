// lib/features/dashboard/presentation/providers/airtime_provider.dart
// Drives the dashboard "Airtime Balance" card + its refresh button.
//   - balanceKes: null until the first successful check, then KES value.
//   - isChecking: true while *144# is dialing (show a spinner on the button).
//   - errorMessage: surfaced if the channel call throws.
// Wiring (in dashboard_screen.dart):
//   refresh button onPressed:  ref.read(airtimeProvider.notifier).refresh()
//   balance text:              ref.watch(airtimeProvider).balanceKes
//   spinner:                   ref.watch(airtimeProvider).isChecking
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/airtime_service.dart';

class AirtimeState {
  final double? balanceKes; // null = not checked yet
  final bool isChecking;
  final String? errorMessage;
  const AirtimeState({
    this.balanceKes,
    this.isChecking = false,
    this.errorMessage,
  });

  AirtimeState copyWith({
    double? balanceKes,
    bool? isChecking,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AirtimeState(
      balanceKes: balanceKes ?? this.balanceKes,
      isChecking: isChecking ?? this.isChecking,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AirtimeNotifier extends StateNotifier<AirtimeState> {
  final AirtimeService _service;
  AirtimeNotifier(this._service) : super(const AirtimeState());

  /// Dial *144# and update the balance. Re-entrancy guarded so rapid taps
  /// don't stack multiple USSD dials.
  Future<void> refresh() async {
    if (state.isChecking) return;
    state = state.copyWith(isChecking: true, clearError: true);
    try {
      final balance = await _service.checkAirtimeBalance();
      state = state.copyWith(balanceKes: balance, isChecking: false);
    } on PlatformException catch (e) {
      state = state.copyWith(
        isChecking: false,
        errorMessage: e.message ?? 'Could not check airtime',
      );
    } catch (_) {
      state = state.copyWith(
        isChecking: false,
        errorMessage: 'Could not check airtime',
      );
    }
  }
}

final airtimeProvider =
    StateNotifierProvider<AirtimeNotifier, AirtimeState>((ref) {
  return AirtimeNotifier(ref.watch(airtimeServiceProvider));
});