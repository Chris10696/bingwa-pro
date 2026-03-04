import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/customer_model.dart';
import '../../../../shared/repositories/customer_repository.dart';

// Customer State
class CustomerState {
  final List<Customer> customers;
  final int currentPage;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final Customer? selectedCustomer;
  final CustomerTransactionSummary? customerSummary;
  final bool isCreating;
  final bool isUpdating;
  final bool isBlacklisting;
  final String? searchQuery;
  final bool isSearching;
  final List<Customer>? searchResults;

  CustomerState({
    this.customers = const [],
    this.currentPage = 1,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.selectedCustomer,
    this.customerSummary,
    this.isCreating = false,
    this.isUpdating = false,
    this.isBlacklisting = false,
    this.searchQuery,
    this.isSearching = false,
    this.searchResults,
  });

  CustomerState copyWith({
    List<Customer>? customers,
    int? currentPage,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    Customer? selectedCustomer,
    CustomerTransactionSummary? customerSummary,
    bool? isCreating,
    bool? isUpdating,
    bool? isBlacklisting,
    String? searchQuery,
    bool? isSearching,
    List<Customer>? searchResults,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      currentPage: currentPage ?? this.currentPage,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      selectedCustomer: selectedCustomer ?? this.selectedCustomer,
      customerSummary: customerSummary ?? this.customerSummary,
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isBlacklisting: isBlacklisting ?? this.isBlacklisting,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
      searchResults: searchResults ?? this.searchResults,
    );
  }
}

// Customer Notifier
class CustomerNotifier extends StateNotifier<CustomerState> {
  final CustomerRepository _repository;
  final Ref _ref;

  CustomerNotifier(this._repository, this._ref) : super(CustomerState());

  // Load customers
  Future<void> loadCustomers({bool reset = true}) async {
    if (reset) {
      state = state.copyWith(isLoading: true, error: null);
    } else {
      state = state.copyWith(isLoadingMore: true, error: null);
    }

    try {
      final filter = CustomerFilter(
        page: reset ? 1 : state.currentPage,
        pageSize: 20,
        sortBy: 'createdAt',
        sortDesc: true,
        searchTerm: state.searchQuery,
      );

      final response = await _repository.getCustomers(filter);

      if (reset) {
        state = state.copyWith(
          customers: response.customers,
          currentPage: 2,
          hasMore: response.hasNextPage,
          isLoading: false,
          isLoadingMore: false,
        );
      } else {
        state = state.copyWith(
          customers: [...state.customers, ...response.customers],
          currentPage: state.currentPage + 1,
          hasMore: response.hasNextPage,
          isLoadingMore: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: 'Failed to load customers: ${e.toString()}',
      );
    }
  }

  // Load more customers (pagination)
  Future<void> loadMoreCustomers() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    await loadCustomers(reset: false);
  }

  // Refresh customers
  Future<void> refreshCustomers() async {
    await loadCustomers(reset: true);
  }

  // Load single customer
  Future<void> loadCustomer(String customerId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final customer = await _repository.getCustomer(customerId);
      final summary = await _repository.getCustomerSummary(customerId);

      state = state.copyWith(
        selectedCustomer: customer,
        customerSummary: summary,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load customer: ${e.toString()}',
      );
    }
  }

  // Create customer
  Future<Customer?> createCustomer(CreateCustomerRequest request) async {
    state = state.copyWith(isCreating: true, error: null);

    try {
      final customer = await _repository.createCustomer(request);

      // Add to list
      state = state.copyWith(
        customers: [customer, ...state.customers],
        isCreating: false,
      );

      return customer;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: 'Failed to create customer: ${e.toString()}',
      );
      return null;
    }
  }

  // Update customer
  Future<Customer?> updateCustomer(String customerId, UpdateCustomerRequest request) async {
    state = state.copyWith(isUpdating: true, error: null);

    try {
      final customer = await _repository.updateCustomer(customerId, request);

      // Update in list
      final updatedCustomers = state.customers.map((c) {
        return c.id == customerId ? customer : c;
      }).toList();

      state = state.copyWith(
        customers: updatedCustomers,
        selectedCustomer: customer,
        isUpdating: false,
      );

      return customer;
    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        error: 'Failed to update customer: ${e.toString()}',
      );
      return null;
    }
  }

  // Blacklist customer
  Future<Customer?> blacklistCustomer(String customerId, String reason) async {
    state = state.copyWith(isBlacklisting: true, error: null);

    try {
      final request = BlacklistRequest(
        customerId: customerId,
        reason: reason,
      );

      final customer = await _repository.blacklistCustomer(request);

      // Update in list
      final updatedCustomers = state.customers.map((c) {
        return c.id == customerId ? customer : c;
      }).toList();

      state = state.copyWith(
        customers: updatedCustomers,
        selectedCustomer: customer,
        isBlacklisting: false,
      );

      return customer;
    } catch (e) {
      state = state.copyWith(
        isBlacklisting: false,
        error: 'Failed to blacklist customer: ${e.toString()}',
      );
      return null;
    }
  }

  // Unblacklist customer
  Future<Customer?> unblacklistCustomer(String customerId) async {
    state = state.copyWith(isBlacklisting: true, error: null);

    try {
      final customer = await _repository.unblacklistCustomer(customerId);

      // Update in list
      final updatedCustomers = state.customers.map((c) {
        return c.id == customerId ? customer : c;
      }).toList();

      state = state.copyWith(
        customers: updatedCustomers,
        selectedCustomer: customer,
        isBlacklisting: false,
      );

      return customer;
    } catch (e) {
      state = state.copyWith(
        isBlacklisting: false,
        error: 'Failed to unblacklist customer: ${e.toString()}',
      );
      return null;
    }
  }

  // Delete customer
  Future<bool> deleteCustomer(String customerId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.deleteCustomer(customerId);

      // Remove from list
      final updatedCustomers = state.customers.where((c) => c.id != customerId).toList();

      state = state.copyWith(
        customers: updatedCustomers,
        selectedCustomer: null,
        customerSummary: null,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete customer: ${e.toString()}',
      );
      return false;
    }
  }

  // Search customers
  Future<void> searchCustomers(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(
        searchQuery: null,
        isSearching: false,
        searchResults: null,
      );
      return;
    }

    state = state.copyWith(
      searchQuery: query,
      isSearching: true,
      error: null,
    );

    try {
      final results = await _repository.searchCustomers(query);

      state = state.copyWith(
        searchResults: results,
        isSearching: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        error: 'Search failed: ${e.toString()}',
      );
    }
  }

  // Clear selected customer
  void clearSelected() {
    state = state.copyWith(
      selectedCustomer: null,
      customerSummary: null,
    );
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider
final customerProvider = StateNotifierProvider<CustomerNotifier, CustomerState>((ref) {
  final repository = ref.read(customerRepositoryProvider);
  return CustomerNotifier(repository, ref);
});