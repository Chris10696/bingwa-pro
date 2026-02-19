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

// State - ADDED 'abstract' keyword
@freezed
abstract class DashboardState with _$DashboardState {
  const factory DashboardState({
    @Default(false) bool isLoading,
    AgentProfile? agent,
    AgentStats? stats,
    WalletBalance? walletBalance,
    List<TransactionDetails>? recentTransactions,
    UssdHealthCheck? ussdHealth,
    List<ProductBundle>? popularProducts,
    @Default(false) bool isProcessing,
    String? errorMessage,
    @Default(0) int activeTab,
    @Default(false) bool showHealthWarning,
    @Default('TODAY') String selectedPeriod,
  }) = _DashboardState;
}

// Notifier - REMOVED unused _ref parameter
class DashboardNotifier extends StateNotifier<DashboardState> {
  final AgentRepository _agentRepository;
  final WalletRepository _walletRepository;
  final TransactionRepository _transactionRepository;
  
  DashboardNotifier(
    this._agentRepository,
    this._walletRepository,
    this._transactionRepository,
  ) : super(const DashboardState());
  
  // Load all dashboard data
  Future<void> loadDashboardData() async {
    if (state.isLoading) return;
    
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      // Load data in parallel
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
        _transactionRepository.getProducts(activeOnly: true),
      ], eagerError: true);
      
      // Cast results to proper types
      final agentProfile = results[0] as AgentProfile?;
      final agentStats = results[1] as AgentStats;
      final walletBalance = results[2] as WalletBalance;
      final transactionHistory = results[3] as TransactionListResponse;
      final ussdHealth = results[4] as UssdHealthCheck;
      final products = results[5] as List<ProductBundle>;
      
      // Extract recent transactions
      final recentTransactions = transactionHistory.transactions;
      
      // Check if we need to show health warning
      final showHealthWarning = ussdHealth.status == UssdStatus.red || 
          (ussdHealth.status == UssdStatus.yellow && ussdHealth.successRate < 0.9);
      
      state = state.copyWith(
        isLoading: false,
        agent: agentProfile,
        stats: agentStats,
        walletBalance: walletBalance,
        recentTransactions: recentTransactions,
        ussdHealth: ussdHealth,
        popularProducts: products.take(3).toList(),
        showHealthWarning: showHealthWarning,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load dashboard data: ${e.toString()}',
      );
    }
  }
  
  // Helper method to get agent profile
  Future<AgentProfile?> _getAgentProfile() async {
    try {
      return await _agentRepository.getAgentProfile();
    } catch (e) {
      print('Failed to load agent profile: $e');
      return null;
    }
  }
  
  // Refresh data
  Future<void> refresh() async {
    await loadDashboardData();
  }
  
  // Change active tab
  void changeTab(int index) {
    state = state.copyWith(activeTab: index);
  }
  
  // Change period filter
  void changePeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
  }
  
  // Get quick stats for the selected period
  Future<Map<String, dynamic>> getQuickStats() async {
    try {
      final stats = await _agentRepository.getAgentStats(period: state.selectedPeriod);
      
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
  
  // Get commission summary
  Future<Map<String, dynamic>> getCommissionSummary() async {
    try {
      return await _agentRepository.getCommissionSummary();
    } catch (e) {
      return {};
    }
  }
  
  // Start processing (when play button is tapped)
  void startProcessing() {
    state = state.copyWith(isProcessing: true);
  }
  
  // Pause processing
  void pauseProcessing() {
    state = state.copyWith(isProcessing: false);
  }
  
  // Stop processing
  void stopProcessing() {
    state = state.copyWith(isProcessing: false);
  }
  
  // Clear error
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

// Providers
final dashboardNotifierProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
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