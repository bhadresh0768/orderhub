import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../../models/delivery_agent.dart';
import '../../../../models/enums.dart';
import '../../../../models/order.dart';
import '../../../../models/payment.dart';
import '../../../../providers.dart';

part 'business_order_detail_state.dart';
part 'business_order_detail_helpers.dart';
part 'business_order_detail_actions.dart';
part 'business_order_detail_build.dart';

class BusinessOrderDetailScreen extends ConsumerStatefulWidget {
  const BusinessOrderDetailScreen({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<BusinessOrderDetailScreen> createState() =>
      _BusinessOrderDetailScreenState();
}

class _BusinessOrderDetailScreenState
    extends ConsumerState<BusinessOrderDetailScreen> {
  ProviderSubscription<AsyncValue<Order?>>? _orderSubscription;
  final Set<TextEditingController> _tapClearedControllers =
      <TextEditingController>{};
  late final TextEditingController _paymentAmountController;
  late final TextEditingController _gstPercentController;
  late final TextEditingController _extraChargesController;
  late List<TextEditingController> _itemPriceControllers;
  late List<TextEditingController> _itemUnavailableReasonControllers;
  late final String _actorName;

  _BusinessOrderUiState get _ui =>
      ref.read(_businessOrderUiProvider(widget.order));

  void _updateUi(
    _BusinessOrderUiState Function(_BusinessOrderUiState state) update,
  ) {
    final notifier = ref.read(_businessOrderUiProvider(widget.order).notifier);
    notifier.state = update(notifier.state);
  }

  Order get _order => _ui.order;
  bool get _saving => _ui.saving;
  PaymentStatus get _selectedPaymentStatus => _ui.selectedPaymentStatus;
  PaymentMethod get _selectedPaymentMethod => _ui.selectedPaymentMethod;
  String? get _selectedDeliveryAgentId => _ui.selectedDeliveryAgentId;
  bool get _collectPaymentOnAssign => _ui.collectPaymentOnAssign;
  List<bool> get _itemGstIncluded => _ui.itemGstIncluded;
  List<bool> get _itemIncluded => _ui.itemIncluded;

  bool get _isLocked =>
      _order.status == OrderStatus.completed ||
      _order.delivery.status == DeliveryStatus.delivered;

  bool get _isAccepted => _order.status != OrderStatus.pending;

  void _syncTextControllersFromOrder(Order order) {
    _paymentAmountController.text =
        order.payment.amount?.toStringAsFixed(2) ?? '';
    _gstPercentController.text = order.gstPercent?.toStringAsFixed(2) ?? '';
    _extraChargesController.text = order.extraCharges?.toStringAsFixed(2) ?? '';

    for (final controller in _itemPriceControllers) {
      controller.dispose();
    }
    _itemPriceControllers = order.items
        .map(
          (item) => TextEditingController(
            text: item.unitPrice?.toStringAsFixed(2) ?? '',
          ),
        )
        .toList();

    for (final controller in _itemUnavailableReasonControllers) {
      controller.dispose();
    }
    _itemUnavailableReasonControllers = order.items
        .map(
          (item) => TextEditingController(text: item.unavailableReason ?? ''),
        )
        .toList();
  }

  void _syncUiFromLatestOrder(Order latestOrder) {
    if (!mounted) return;
    _updateUi(
      (state) => state.copyWith(
        order: latestOrder,
        selectedPaymentStatus: latestOrder.payment.status,
        selectedPaymentMethod: latestOrder.payment.method,
        selectedDeliveryAgentId: latestOrder.assignedDeliveryAgentId,
        itemGstIncluded: latestOrder.items
            .map((item) => item.gstIncluded ?? false)
            .toList(),
        itemIncluded: latestOrder.items
            .map((item) => item.isIncluded ?? true)
            .toList(),
        refreshTick: state.refreshTick + 1,
      ),
    );
    _syncTextControllersFromOrder(latestOrder);
  }

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _actorName =
        ref.read(authStateProvider).value?.displayName?.trim().isNotEmpty ==
            true
        ? ref.read(authStateProvider).value!.displayName!.trim()
        : 'Business Owner';
    _paymentAmountController = TextEditingController(
      text: order.payment.amount?.toStringAsFixed(2) ?? '',
    );
    _gstPercentController = TextEditingController(
      text: order.gstPercent?.toStringAsFixed(2) ?? '',
    );
    _extraChargesController = TextEditingController(
      text: order.extraCharges?.toStringAsFixed(2) ?? '',
    );
    _itemPriceControllers = order.items
        .map(
          (item) => TextEditingController(
            text: item.unitPrice?.toStringAsFixed(2) ?? '',
          ),
        )
        .toList();
    _itemUnavailableReasonControllers = order.items
        .map(
          (item) => TextEditingController(text: item.unavailableReason ?? ''),
        )
        .toList();
    _orderSubscription = ref.listenManual<AsyncValue<Order?>>(
      orderByIdProvider(widget.order.id),
      (_, next) {
        next.whenData((latestOrder) {
          if (latestOrder == null) return;
          _syncUiFromLatestOrder(latestOrder);
        });
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _orderSubscription?.close();
    _paymentAmountController.dispose();
    _gstPercentController.dispose();
    _extraChargesController.dispose();
    for (final controller in _itemPriceControllers) {
      controller.dispose();
    }
    for (final controller in _itemUnavailableReasonControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _buildContent(context);
}
