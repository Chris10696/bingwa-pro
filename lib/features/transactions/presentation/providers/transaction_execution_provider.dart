import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:bingwa_pro/shared/models/transaction_model.dart';
import 'package:bingwa_pro/shared/repositories/transaction_repository.dart';
import 'package:bingwa_pro/features/auth/presentation/providers/auth_provider.dart';
import 'package:bingwa_pro/core/security/device_fingerprint.dart';

class TransactionExecutionState {
  final List<ProductBundle>? availableProducts;
  final String customerPhone;
  final double? amount;
  final ProductBundle? selectedProduct;
  final TransactionType? transactionType;
  final UssdHealthCheck? ussdHealth;
  final bool isLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final bool showConfirmation;
  final TransactionResponse? lastResponse;
  final String transactionStatus; // New: track transaction status for state machine

  TransactionExecutionState({
    this.availableProducts,
    this.customerPhone = '',
    this.amount,
    this.selectedProduct,
    this.transactionType,
    this.ussdHealth,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.showConfirmation = false,
    this.lastResponse,
    this.transactionStatus = 'idle',
  });

  TransactionExecutionState copyWith({
    List<ProductBundle>? availableProducts,
    String? customerPhone,
    double? amount,
    ProductBundle? selectedProduct,
    TransactionType? transactionType,
    UssdHealthCheck? ussdHealth,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    bool? showConfirmation,
    TransactionResponse? lastResponse,
    String? transactionStatus,
  }) {
    return TransactionExecutionState(
      availableProducts: availableProducts ?? this.availableProducts,
      customerPhone: customerPhone ?? this.customerPhone,
      amount: amount ?? this.amount,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      transactionType: transactionType ?? this.transactionType,
      ussdHealth: ussdHealth ?? this.ussdHealth,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
      showConfirmation: showConfirmation ?? this.showConfirmation,
      lastResponse: lastResponse ?? this.lastResponse,
      transactionStatus: transactionStatus ?? this.transactionStatus,
    );
  }
}

class TransactionExecutionNotifier extends StateNotifier<TransactionExecutionState> {
  final TransactionRepository _repository;
  final Ref _ref;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  TransactionExecutionNotifier(this._repository, this._ref) : super(TransactionExecutionState());

  Future<void> loadInitialData() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null, transactionStatus: 'loading');
      
      // Load available products and USSD health status in parallel
      final results = await Future.wait([
        _repository.getProducts(activeOnly: true),
        _repository.getUssdHealthStatus(),
      ], eagerError: true);
      
      // Explicitly cast the results to their correct types
      final products = results[0] as List<ProductBundle>;
      final ussdHealth = results[1] as UssdHealthCheck;
      
      state = state.copyWith(
        isLoading: false,
        availableProducts: products,
        ussdHealth: ussdHealth,
        transactionStatus: 'ready',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load initial data: ${e.toString()}',
        transactionStatus: 'error',
      );
    }
  }

  void selectTransactionType(TransactionType type) {
    state = state.copyWith(transactionType: type);
  }

  void updateCustomerPhone(String phone) {
    state = state.copyWith(customerPhone: phone);
  }

  void updateAmount(double amount) {
    state = state.copyWith(amount: amount);
  }

  void selectProduct(ProductBundle product) {
    state = state.copyWith(
      selectedProduct: product,
      amount: product.price,
    );
  }

  // FIXED: Get agent ID from auth state (Line 125)
  Future<String> _getAgentId() async {
    try {
      final authState = _ref.read(authNotifierProvider);
      return authState.agent?.id ?? '';
    } catch (e) {
      return '';
    }
  }

  // FIXED: Get device ID from device info (Line 133)
  Future<String> _getDeviceId() async {
    try {
      // First try to get from DeviceFingerprint
      final deviceId = await DeviceFingerprint.generateDeviceId();
      if (deviceId.isNotEmpty) {
        return deviceId;
      }
      
      // Fallback to device info
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.id;
    } catch (e) {
      // Last resort fallback
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> executeTransaction() async {
    if (state.isSubmitting || 
        state.customerPhone.isEmpty || 
        state.amount == null || 
        state.amount! <= 0) {
      return;
    }

    try {
      state = state.copyWith(
        isSubmitting: true, 
        errorMessage: null, 
        transactionStatus: 'initiated'
      );
      
      // Get agent ID and device ID
      final agentId = await _getAgentId();
      final deviceId = await _getDeviceId();
      
      if (agentId.isEmpty) {
        throw Exception('Agent ID not found. Please login again.');
      }
      
      // Create transaction request with real IDs
      final request = TransactionRequest(
        agentId: agentId,
        type: state.transactionType ?? TransactionType.airtime,
        customerPhone: state.customerPhone,
        amount: state.amount!,
        productId: state.selectedProduct?.id ?? '',
        productName: state.selectedProduct?.name ?? 'Airtime',
        bundleSize: state.selectedProduct?.value,
        ussdCode: state.selectedProduct?.ussdCode ?? '*144*1*1*1#',
        deviceId: deviceId,
      );

      state = state.copyWith(transactionStatus: 'executing');

      // Execute based on transaction type
      TransactionResponse response;
      switch (state.transactionType) {
        case TransactionType.airtime:
          response = await _repository.executeAirtime(request);
          break;
        case TransactionType.data:
          response = await _repository.executeData(request);
          break;
        case TransactionType.sms:
          response = await _repository.executeSms(request);
          break;
        default:
          response = await _repository.executeAirtime(request);
      }

      state = state.copyWith(
        isSubmitting: false,
        showConfirmation: true,
        lastResponse: response,
        transactionStatus: response.status == TransactionStatus.success ? 'success' : 'failed',
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Transaction failed: ${e.toString()}',
        transactionStatus: 'error',
      );
    }
  }

  void clearConfirmation() {
    state = state.copyWith(
      showConfirmation: false,
      lastResponse: null,
    );
  }

  void resetForm() {
    state = TransactionExecutionState(
      availableProducts: state.availableProducts,
      ussdHealth: state.ussdHealth,
    );
  }

  // New method to check USSD health before transaction
  Future<bool> isUssdHealthy() async {
    try {
      if (state.ussdHealth == null) {
        await loadInitialData();
      }
      return state.ussdHealth?.status == UssdStatus.green;
    } catch (e) {
      return false;
    }
  }

  // New method to get transaction status
  String getTransactionStatus() {
    return state.transactionStatus;
  }
}

final transactionExecutionProvider = StateNotifierProvider<TransactionExecutionNotifier, TransactionExecutionState>((ref) {
  final repository = ref.read(transactionRepositoryProvider);
  return TransactionExecutionNotifier(repository, ref);
});