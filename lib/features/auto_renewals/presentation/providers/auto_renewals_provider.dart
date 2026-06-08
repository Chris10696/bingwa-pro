// lib/features/auto_renewals/presentation/providers/auto_renewals_provider.dart
// W2.4D: auto-renewals = scheduled transactions (D-W2-5). Wraps the
// transaction_repository scheduled methods (Batch 3). A "renewal" is a
// SCHEDULED transaction whose rescheduleInfo carries {scheduledFor,
// isRecurring, daysRemaining}.
//
// W3.E: this is the ONLY caller of repository.schedule()/cancelScheduled(), so
// it's where the device-side firing is armed. After a schedule succeeds we arm a
// WorkManager one-shot (ScheduleService) keyed by the new transaction id so the
// row fires at scheduledFor; cancelling tears the armed job down. Arming is
// best-effort and never throws into the schedule flow (the row is already
// persisted server-side).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/transaction_model.dart';
import '../../../../shared/repositories/transaction_repository.dart';
import '../../../../core/services/schedule_service.dart';
class AutoRenewalsState {
  final bool isLoading;
  final List<ScheduledTransaction> renewals;
  final String? errorMessage;
  final bool isMutating; // schedule/cancel in flight
  const AutoRenewalsState({
    this.isLoading = false,
    this.renewals = const [],
    this.errorMessage,
    this.isMutating = false,
  });
  AutoRenewalsState copyWith({
    bool? isLoading,
    List<ScheduledTransaction>? renewals,
    String? errorMessage,
    bool clearError = false,
    bool? isMutating,
  }) {
    return AutoRenewalsState(
      isLoading: isLoading ?? this.isLoading,
      renewals: renewals ?? this.renewals,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isMutating: isMutating ?? this.isMutating,
    );
  }
}
class AutoRenewalsNotifier extends StateNotifier<AutoRenewalsState> {
  final TransactionRepository _repository;
  final ScheduleService _scheduleService;
  AutoRenewalsNotifier(this._repository, this._scheduleService)
      : super(const AutoRenewalsState());
  Future<void> loadRenewals() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final renewals = await _repository.getScheduled();
      state = state.copyWith(isLoading: false, renewals: renewals);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load auto renewals: ${e.toString()}',
      );
    }
  }

  Future<bool> schedule({
    required String offerId,
    required String customerPhone,
    required DateTime scheduledFor,
    required bool isRecurring,
    int? daysToRecur,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final created = await _repository.schedule(
        ScheduleTransactionRequest(
          offerId: offerId,
          customerPhone: customerPhone,
          scheduledFor: scheduledFor.toIso8601String(),
          isRecurring: isRecurring,
          daysToRecur: daysToRecur,
        ),
      );
      // W3.E: arm device-side firing for the freshly-created row. Best-effort —
      // ScheduleService swallows its own errors, so this never throws here.
      await _scheduleService.arm(
        transactionId: created.id,
        scheduledFor: scheduledFor,
      );
      state = state.copyWith(isMutating: false);
      await loadRenewals();
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        errorMessage: 'Failed to schedule: ${e.toString()}',
      );
      return false;
    }
  }
  Future<bool> cancel(String id) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      await _repository.cancelScheduled(id);
      // W3.E: tear down the armed device-side job for this row.
      await _scheduleService.cancel(id);
      state = state.copyWith(
        isMutating: false,
        renewals: [
          for (final r in state.renewals)
            if (r.id != id) r,
        ],
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isMutating: false,
        errorMessage: 'Failed to cancel: ${e.toString()}',
      );
      return false;
    }
  }
  void clearError() => state = state.copyWith(clearError: true);
}
final autoRenewalsNotifierProvider =
    StateNotifierProvider<AutoRenewalsNotifier, AutoRenewalsState>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final scheduleService = ref.watch(scheduleServiceProvider);
  return AutoRenewalsNotifier(repository, scheduleService);
});