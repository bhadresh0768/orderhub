part of 'business_home.dart';

extension _BusinessOrdersTabFilters on _BusinessOrdersTabState {
  bool get _isCompletedTab {
    return widget.allowedStatuses.length == 1 &&
        widget.allowedStatuses.first == OrderStatus.completed;
  }

  DateTime _effectiveCompletedAt(Order order) {
    return order.delivery.deliveredAt ??
        order.updatedAt ??
        order.createdAt ??
        DateTime.now();
  }

  bool _matchesCompletedDateFilter(
    Order order,
    OrderDateFilterOption filter,
    DateTime now,
  ) {
    if (filter == OrderDateFilterOption.all) return true;
    final effectiveDate = _effectiveCompletedAt(order);
    final ui = ref.read(_businessOrdersUiProvider(_uiKey));
    return OrderSharedHelpers.matchesDateFilter(
      effectiveDate,
      filter,
      now,
      customFrom: ui.completedFromDate,
      customTo: ui.completedToDate,
    );
  }

  Future<void> _pickCompletedCustomRange(_BusinessOrdersUiState ui) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      initialDateRange:
          (ui.completedFromDate != null && ui.completedToDate != null)
          ? DateTimeRange(
              start: ui.completedFromDate!,
              end: ui.completedToDate!,
            )
          : null,
    );
    if (picked == null || !mounted) return;
    ref.read(_businessOrdersUiProvider(_uiKey).notifier).state = ui.copyWith(
      completedDateFilter: OrderDateFilterOption.custom,
      completedFromDate: picked.start,
      completedToDate: picked.end,
    );
  }

  OrderStatus _effectiveOrderStatus(Order order) {
    return OrderSharedHelpers.effectiveStatus(
      order,
      normalizeApprovedToInProgress: true,
    );
  }

  String _requestedByAddress(Order order) {
    String appendCityIfMissing(String address, String city) {
      final cleanAddress = address.trim();
      final cleanCity = city.trim();
      if (cleanAddress.isEmpty) return cleanCity;
      if (cleanCity.isEmpty) return cleanAddress;
      if (cleanAddress.toLowerCase().contains(cleanCity.toLowerCase())) {
        return cleanAddress;
      }
      return '$cleanAddress, $cleanCity';
    }

    final ownerBusinessId = widget.profile.businessId;
    final ownerBusiness = ownerBusinessId == null
        ? null
        : ref.watch(businessByIdProvider(ownerBusinessId)).asData?.value;
    final ownerCity = (ownerBusiness?.city ?? '').trim();

    final direct = (order.deliveryAddress ?? '').trim();
    if (direct.isNotEmpty) {
      return appendCityIfMissing(direct, ownerCity);
    }

    if (order.requesterType == OrderRequesterType.businessOwner) {
      final requesterBusinessId = order.requesterBusinessId;
      if (requesterBusinessId == null || requesterBusinessId.isEmpty) {
        return '-';
      }
      final businessAsync = ref.watch(businessByIdProvider(requesterBusinessId));
      final business = businessAsync.asData?.value;
      final address = (business?.address ?? '').trim();
      final city = (business?.city ?? '').trim();
      if (address.isEmpty && city.isEmpty) return '-';
      if (address.isEmpty) return city;
      if (city.isEmpty) return address;
      return '$address, $city';
    }
    final profileAddress = (_customerProfile(order)?.address ?? '').trim();
    if (profileAddress.isNotEmpty) {
      return appendCityIfMissing(profileAddress, ownerCity);
    }
    if (ownerCity.isNotEmpty) return ownerCity;
    return '-';
  }

  AppUser? _customerProfile(Order order) {
    if (order.requesterType != OrderRequesterType.customer) {
      return null;
    }
    return ref.watch(userProfileProvider(order.customerId)).asData?.value;
  }

  String? _customerShopName(Order order) {
    final shopName = (_customerProfile(order)?.shopName ?? '').trim();
    if (shopName.isEmpty) return null;
    if (shopName.toLowerCase() == order.customerName.trim().toLowerCase()) {
      return null;
    }
    return shopName;
  }

  String? _paymentCollectorLabel(Order order) {
    final collectedBy = order.payment.collectedBy;
    if (collectedBy == null || order.payment.status != PaymentStatus.done) {
      return null;
    }
    final who = collectedBy == PaymentCollectedBy.deliveryBoy
        ? 'Delivery Boy'
        : 'Business';
    final whoName = (order.payment.collectedByName ?? '').trim();
    if (whoName.isEmpty) return who;
    return '$who ($whoName)';
  }
}
