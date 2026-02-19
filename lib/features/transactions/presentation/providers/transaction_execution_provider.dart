import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bingwa_pro/shared/models/transaction_model.dart';
import 'package:bingwa_pro/shared/repositories/transaction_repository.dart';

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
      errorMessage: errorMessage,
      showConfirmation: showConfirmation ?? this.showConfirmation,
      lastResponse: lastResponse ?? this.lastResponse,
    );
  }
}

class TransactionExecutionNotifier extends StateNotifier<TransactionExecutionState> {
  final TransactionRepository _repository;

  TransactionExecutionNotifier(this._repository) : super(TransactionExecutionState());

  Future<void> loadInitialData() async {
    try {
      state = state.copyWith(isLoading: true, errorMessage: null);
      
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
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load initial data: ${e.toString()}',
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

  Future<void> executeTransaction() async {
    if (state.isSubmitting || 
        state.customerPhone.isEmpty || 
        state.amount == null || 
        state.amount! <= 0) {
      return;
    }

    try {
      state = state.copyWith(isSubmitting: true, errorMessage: null);
      
      // Create transaction request
      final request = TransactionRequest(
        agentId: 'current_agent', // TODO: Get from auth state
        type: state.transactionType ?? TransactionType.airtime,
        customerPhone: state.customerPhone,
        amount: state.amount!,
        productId: state.selectedProduct?.id ?? '',
        productName: state.selectedProduct?.name ?? 'Airtime',
        bundleSize: state.selectedProduct?.value,
        ussdCode: state.selectedProduct?.ussdCode ?? '*144*1*1*1#',
        deviceId: 'device_id', // TODO: Get from device info
      );

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
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Transaction failed: ${e.toString()}',
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
}

final transactionExecutionProvider = StateNotifierProvider<TransactionExecutionNotifier, TransactionExecutionState>((ref) {
  final repository = ref.read(transactionRepositoryProvider);
  return TransactionExecutionNotifier(repository);
});