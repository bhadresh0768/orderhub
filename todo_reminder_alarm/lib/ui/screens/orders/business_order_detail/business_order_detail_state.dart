part of 'business_order_detail_screen.dart';

final _businessOrderUiProvider = StateProvider.autoDispose
    .family<_BusinessOrderUiState, Order>(
      (ref, order) => _BusinessOrderUiState(
        order: order,
        selectedPaymentStatus: order.payment.status,
        selectedPaymentMethod: order.payment.method,
        selectedDeliveryAgentId: order.assignedDeliveryAgentId,
        itemGstIncluded: order.items
            .map((item) => item.gstIncluded ?? false)
            .toList(),
        itemIncluded: order.items
            .map((item) => item.isIncluded ?? true)
            .toList(),
      ),
    );

class _BusinessOrderUiState {
  const _BusinessOrderUiState({
    required this.order,
    required this.selectedPaymentStatus,
    required this.selectedPaymentMethod,
    required this.itemGstIncluded,
    required this.itemIncluded,
    this.selectedDeliveryAgentId,
    this.collectPaymentOnAssign = false,
    this.saving = false,
    this.refreshTick = 0,
  });

  final Order order;
  final bool saving;
  final PaymentStatus selectedPaymentStatus;
  final PaymentMethod selectedPaymentMethod;
  final String? selectedDeliveryAgentId;
  final bool collectPaymentOnAssign;
  final List<bool> itemGstIncluded;
  final List<bool> itemIncluded;
  final int refreshTick;

  _BusinessOrderUiState copyWith({
    Order? order,
    bool? saving,
    PaymentStatus? selectedPaymentStatus,
    PaymentMethod? selectedPaymentMethod,
    Object? selectedDeliveryAgentId = _businessOrderUnset,
    bool? collectPaymentOnAssign,
    List<bool>? itemGstIncluded,
    List<bool>? itemIncluded,
    int? refreshTick,
  }) {
    return _BusinessOrderUiState(
      order: order ?? this.order,
      saving: saving ?? this.saving,
      selectedPaymentStatus:
          selectedPaymentStatus ?? this.selectedPaymentStatus,
      selectedPaymentMethod:
          selectedPaymentMethod ?? this.selectedPaymentMethod,
      selectedDeliveryAgentId: selectedDeliveryAgentId == _businessOrderUnset
          ? this.selectedDeliveryAgentId
          : selectedDeliveryAgentId as String?,
      collectPaymentOnAssign:
          collectPaymentOnAssign ?? this.collectPaymentOnAssign,
      itemGstIncluded: itemGstIncluded ?? this.itemGstIncluded,
      itemIncluded: itemIncluded ?? this.itemIncluded,
      refreshTick: refreshTick ?? this.refreshTick,
    );
  }
}

const _businessOrderUnset = Object();
