import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/order.dart';
import '../providers.dart';

class OrderStatusListener extends ConsumerStatefulWidget {
  const OrderStatusListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OrderStatusListener> createState() =>
      _OrderStatusListenerState();
}

class _OrderStatusListenerState extends ConsumerState<OrderStatusListener> {
  final Map<String, String> _orderSignatures = {};
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      ref.read(notificationServiceProvider).init();
    }
  }

  void _checkForUpdates(List<Order> orders) {
    final notifier = ref.read(notificationServiceProvider);
    for (final order in orders) {
      final signature =
          '${order.status.name}|${order.payment.status.name}|${order.delivery.status.name}';
      final previous = _orderSignatures[order.id];
      if (previous != null && previous != signature) {
        notifier.showStatusUpdate(
          id: order.id.hashCode,
          title: 'Order ${order.displayOrderNumber} Updated',
          body:
              'Status: ${order.status.name}, Payment: ${order.payment.status.name}, Delivery: ${order.delivery.status.name}',
        );
      }
      _orderSignatures[order.id] = signature;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return widget.child;

    final profile = ref.watch(userProfileProvider(user.uid)).value;
    if (profile == null) return widget.child;

    if (profile.role == UserRole.customer) {
      final orders =
          ref.watch(ordersForCustomerProvider(profile.id)).value ??
          const <Order>[];
      _checkForUpdates(orders);
    } else if (profile.role == UserRole.businessOwner &&
        profile.businessId != null) {
      final orders =
          ref.watch(ordersForBusinessProvider(profile.businessId!)).value ??
          const <Order>[];
      _checkForUpdates(orders);
    }
    return widget.child;
  }
}
