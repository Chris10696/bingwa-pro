// lib/features/customers/presentation/providers/customer_provider.dart
// W4-batch-3b — reshaped to the Hybrid-minimal model. The backend returns a flat list
// (≤200, ordered by lastPurchaseTime desc), so there is no client pagination/summary.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/customer_model.dart';
import '../../../../shared/repositories/customer_repository.dart';

class CustomerState {
  final List<Customer> customers;
  final bool isLoading;
  final String? error;
  final Customer? selectedCustomer;
  final bool isUpdating;
  final bool isBlacklisting;
  final List<Customer> searchResults;
  final bool isSearching;

  const CustomerState({
    this.customers = const [],
    this.isLoading = false,
    this.error,
    this.selectedCustomer,
    this.isUpdating = false,
    this.isBlacklisting = false,
    this.searchResults = const [],
    this.isSearching = false,
  });

  /// Customers that are NOT blacklisted (the "blacklistable" list on the BlackList screen).
  List<Customer> get activeCustomers =>
      customers.where((c) => !c.isBlackListed).toList();

  /// Currently-blacklisted customers.
  List<Customer> get blacklistedCustomers =>
      customers.where((c) => c.isBlackListed).toList();

  CustomerState copyWith({
    List<Customer>? customers,
    bool? isLoading,
    String? error,
    bool clearError = false,
    Customer? selectedCustomer,
    bool clearSelected = false,
    bool? isUpdating,
    bool? isBlacklisting,
    List<Customer>? searchResults,
    bool? isSearching,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      selectedCustomer:
          clearSelected ? null : (selectedCustomer ?? this.selectedCustomer),
      isUpdating: isUpdating ?? this.isUpdating,
      isBlacklisting: isBlacklisting ?? this.isBlacklisting,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
    );
  }
}

class CustomerNotifier extends StateNotifier<CustomerState> {
  final CustomerRepository _repository;
  CustomerNotifier(this._repository) : super(const CustomerState());

  Future<void> loadCustomers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await _repository.getCustomers(const CustomerFilter());
      state = state.copyWith(customers: resp.customers, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load customers: $e',
      );
    }
  }

  Future<void> loadCustomer(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final customer = await _repository.getCustomer(id);
      state = state.copyWith(selectedCustomer: customer, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load customer: $e',
      );
    }
  }

  Future<Customer?> updateCustomer(
    String id,
    UpdateCustomerRequest request,
  ) async {
    state = state.copyWith(isUpdating: true, clearError: true);
    try {
      final customer = await _repository.updateCustomer(id, request);
      state = state.copyWith(
        customers: _replace(customer),
        selectedCustomer: customer,
        isUpdating: false,
      );
      return customer;
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: 'Failed to update: $e');
      return null;
    }
  }

  Future<Customer?> blacklistCustomer(String id) => _setBlacklist(id, true);
  Future<Customer?> unblacklistCustomer(String id) => _setBlacklist(id, false);

  Future<Customer?> _setBlacklist(String id, bool blacklist) async {
    state = state.copyWith(isBlacklisting: true, clearError: true);
    try {
      final customer = blacklist
          ? await _repository.blacklistCustomer(id)
          : await _repository.unblacklistCustomer(id);
      state = state.copyWith(
        customers: _replace(customer),
        selectedCustomer: customer,
        isBlacklisting: false,
      );
      return customer;
    } catch (e) {
      state =
          state.copyWith(isBlacklisting: false, error: 'Blacklist failed: $e');
      return null;
    }
  }

  Future<bool> deleteCustomer(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.deleteCustomer(id);
      state = state.copyWith(
        customers: state.customers.where((c) => c.id != id).toList(),
        isLoading: false,
        clearSelected: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to delete: $e');
      return false;
    }
  }

  /// Used by Quick Dial autocomplete + the BlackList search box.
  Future<void> searchCustomers(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: const [], isSearching: false);
      return;
    }
    state = state.copyWith(isSearching: true);
    try {
      final results = await _repository.searchCustomers(query.trim());
      state = state.copyWith(searchResults: results, isSearching: false);
    } catch (e) {
      state = state.copyWith(isSearching: false, error: 'Search failed: $e');
    }
  }

  List<Customer> _replace(Customer updated) =>
      state.customers.map((c) => c.id == updated.id ? updated : c).toList();

  void clearError() => state = state.copyWith(clearError: true);
}

final customerProvider =
    StateNotifierProvider<CustomerNotifier, CustomerState>((ref) {
  return CustomerNotifier(ref.read(customerRepositoryProvider));
});
