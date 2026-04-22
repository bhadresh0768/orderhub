part of 'business_home.dart';

final _businessOrdersUiProvider = StateProvider.autoDispose
    .family<_BusinessOrdersUiState, String>(
      (ref, _) => const _BusinessOrdersUiState(),
    );

class _BusinessOrdersUiState {
  const _BusinessOrdersUiState({
    this.searchQuery = '',
    this.completedDateFilter = OrderDateFilterOption.all,
    this.completedFromDate,
    this.completedToDate,
  });
  final String searchQuery;
  final OrderDateFilterOption completedDateFilter;
  final DateTime? completedFromDate;
  final DateTime? completedToDate;
  _BusinessOrdersUiState copyWith({
    String? searchQuery,
    OrderDateFilterOption? completedDateFilter,
    Object? completedFromDate = _businessDateUnset,
    Object? completedToDate = _businessDateUnset,
  }) {
    return _BusinessOrdersUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      completedDateFilter: completedDateFilter ?? this.completedDateFilter,
      completedFromDate: completedFromDate == _businessDateUnset
          ? this.completedFromDate
          : completedFromDate as DateTime?,
      completedToDate: completedToDate == _businessDateUnset
          ? this.completedToDate
          : completedToDate as DateTime?,
    );
  }
}

const _businessDateUnset = Object();

final _fiscalYearBannerDismissedProvider = StateProvider.autoDispose
    .family<bool, String>((ref, _) => false);

final _placeOrdersUiProvider = StateProvider.autoDispose
    .family<_PlaceOrdersUiState, String>(
      (ref, _) => const _PlaceOrdersUiState(),
    );

class _PlaceOrdersUiState {
  const _PlaceOrdersUiState({
    this.searchQuery = '',
    this.categoryFilter = 'All',
    this.cityFilter = 'All',
    this.placedDateFilter = OrderDateFilterOption.all,
    this.placedFromDate,
    this.placedToDate,
  });
  final String searchQuery;
  final String categoryFilter;
  final String cityFilter;
  final OrderDateFilterOption placedDateFilter;
  final DateTime? placedFromDate;
  final DateTime? placedToDate;
  _PlaceOrdersUiState copyWith({
    String? searchQuery,
    String? categoryFilter,
    String? cityFilter,
    OrderDateFilterOption? placedDateFilter,
    Object? placedFromDate = _businessDateUnset,
    Object? placedToDate = _businessDateUnset,
  }) {
    return _PlaceOrdersUiState(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      cityFilter: cityFilter ?? this.cityFilter,
      placedDateFilter: placedDateFilter ?? this.placedDateFilter,
      placedFromDate: placedFromDate == _businessDateUnset
          ? this.placedFromDate
          : placedFromDate as DateTime?,
      placedToDate: placedToDate == _businessDateUnset
          ? this.placedToDate
          : placedToDate as DateTime?,
    );
  }
}

final _deliveryTeamUiProvider = StateProvider.autoDispose
    .family<_DeliveryTeamUiState, String>(
      (ref, _) => _DeliveryTeamUiState(selectedCountry: Country.parse('IN')),
    );

class _DeliveryTeamUiState {
  const _DeliveryTeamUiState({
    required this.selectedCountry,
    this.editingAgentId,
    this.saving = false,
    this.error,
  });
  final Country selectedCountry;
  final String? editingAgentId;
  final bool saving;
  final String? error;
  _DeliveryTeamUiState copyWith({
    Country? selectedCountry,
    Object? editingAgentId = _businessHomeUnset,
    bool? saving,
    Object? error = _businessHomeUnset,
  }) {
    return _DeliveryTeamUiState(
      selectedCountry: selectedCountry ?? this.selectedCountry,
      editingAgentId: editingAgentId == _businessHomeUnset
          ? this.editingAgentId
          : editingAgentId as String?,
      saving: saving ?? this.saving,
      error: error == _businessHomeUnset ? this.error : error as String?,
    );
  }
}

const _businessHomeUnset = Object();
