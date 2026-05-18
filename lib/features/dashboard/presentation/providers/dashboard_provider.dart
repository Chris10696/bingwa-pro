// lib/features/dashboard/presentation/providers/dashboard_provider.dart
// W1 edits:
//   - Dropped `popularProducts` state field (UI section removed)
//   - Dropped getProducts() call from loadDashboardData parallel fetch
//   - Results array reindexed (5 elements instead of 6)
// All other methods preserved verbatim.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '/../../shared/models/auth_model.dart';
import '/../../shared/models/agent_model.dart';
import '/../../shared/models/transaction_model.dart';
import '/../../shared/models/wallet_model.dart';
import '/../../shared/repositories/agent_repository.dart';
import '/../../shared/repositories/transaction_repository.dart';
import '/../../shared/repositories/wallet_repository.dart';
part 'dashboard_provider.freezed.dart';

@freezed
abstract class DashboardState with _$DashboardState {
  const factory DashboardState({
    @Default(false) bool isLoading,
    AgentProfile? agent,
    AgentStats? stats,
    WalletBalance? walletBalance,
    List<TransactionDetails>? recentTransactions,
    UssdHealthCheck? ussdHealth,
    @Default(false) bool isProcessing,
    String? errorMessage,
    @Default(0) int activeTab,
    @Default(false) bool showHealthWarning,
    @Default('TODAY') String selectedPeriod,
  }) = _DashboardState;
}

class DashboardNotifier extends StateNotifier<DashboardState> {
  final AgentRepository _agentRepository;
  final WalletRepository _walletRepository;
  final TransactionRepository _transactionRepository;

  DashboardNotifier(
    this._agentRepository,
    this._walletRepository,
    this._transactionRepository,
  ) : super(const DashboardState());

  Future<void> loadDashboardData() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // W1: parallel fetch reduced from 6 to 5 (dropped getProducts).
      final results = await Future.wait([
        _getAgentProfile(),
        _agentRepository.getAgentStats(),
        _walletRepository.getWalletBalance(),
        _transactionRepository.getTransactionHistory(
          TransactionFilter(
            page: 1,
            pageSize: 5,
            sortBy: 'createdAt',
            sortDesc: true,
          ),
        ),
        _transactionRepository.getUssdHealthStatus(),
      ], eagerError: true);

      final agentProfile = results[0] as AgentProfile?;
      final agentStats = results[1] as AgentStats;
      final walletBalance = results[2] as WalletBalance;
      final transactionHistory = results[3] as TransactionListResponse;
      final ussdHealth = results[4] as UssdHealthCheck;

      final recentTransactions = transactionHistory.transactions;

      final showHealthWarning = ussdHealth.status == UssdStatus.red ||
          (ussdHealth.status == UssdStatus.yellow &&
              ussdHealth.successRate < 0.9);

      state = state.copyWith(
        isLoading: false,
        agent: agentProfile,
        stats: agentStats,
        walletBalance: walletBalance,
        recentTransactions: recentTransactions,
        ussdHealth: ussdHealth,
        showHealthWarning: showHealthWarning,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dashboard data: ${e.toString()}',
      );
    }
  }

  Future<AgentProfile?> _getAgentProfile() async {
    try {
      return await _agentRepository.getAgentProfile();
    } catch (e) {
      // TODO(wave-5): replace print with AppLogger.e once W5 logging cleanup ships.
      // ignore: avoid_print
      print('Failed to load agent profile: $e');
      return null;
    }
  }

  Future<void> refresh() async {
    await loadDashboardData();
  }

  void changeTab(int index) {
    state = state.copyWith(activeTab: index);
  }

  void changePeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
  }

  Future<Map<String, dynamic>> getQuickStats() async {
    try {
      final stats =
          await _agentRepository.getAgentStats(period: state.selectedPeriod);
      return {
        'totalSales': stats.todaySales,
        'successfulTransactions': stats.successfulTransactions,
        'failedTransactions': stats.failedTransactions,
        'commission': stats.todayCommission,
        'successRate': stats.successRate,
      };
    } catch (e) {
      return {
        'totalSales': 0.0,
        'successfulTransactions': 0,
        'failedTransactions': 0,
        'commission': 0.0,
        'successRate': 0.0,
      };
    }
  }

  // Pass-through to agent_repository — primer W5 deferral keeps this intact.
  Future<Map<String, dynamic>> getCommissionSummary() async {
    try {
      return await _agentRepository.getCommissionSummary();
    } catch (e) {
      return {};
    }
  }

  void startProcessing() {
    state = state.copyWith(isProcessing: true);
  }

  void pauseProcessing() {
    state = state.copyWith(isProcessing: false);
  }

  void stopProcessing() {
    state = state.copyWith(isProcessing: false);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final agentRepository = ref.watch(agentRepositoryProvider);
  final walletRepository = ref.watch(walletRepositoryProvider);
  final transactionRepository = ref.watch(transactionRepositoryProvider);
  return DashboardNotifier(
    agentRepository,
    walletRepository,
    transactionRepository,
  );
});

final dashboardAgentProvider = Provider<AgentProfile?>((ref) {
  return ref.watch(dashboardNotifierProvider).agent;
});

final dashboardStatsProvider = Provider<AgentStats?>((ref) {
  return ref.watch(dashboardNotifierProvider).stats;
});

final dashboardBalanceProvider = Provider<WalletBalance?>((ref) {
  return ref.watch(dashboardNotifierProvider).walletBalance;
});

final ussdHealthProvider = Provider<UssdHealthCheck?>((ref) {
  return ref.watch(dashboardNotifierProvider).ussdHealth;
});