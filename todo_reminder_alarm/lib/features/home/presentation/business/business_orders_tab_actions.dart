part of 'business_home.dart';

extension _BusinessOrdersTabActions on _BusinessOrdersTabState {
  String _paymentMethodLabel(PaymentMethod method) {
    return OrderSharedHelpers.paymentMethodLabel(method);
  }

  Future<(PaymentStatus, PaymentMethod)?> _askPaymentOnDelivery(
    BuildContext context,
    Order order,
  ) async {
    var selectedStatus = order.payment.status;
    var selectedMethod = order.payment.method;
    return showDialog<(PaymentStatus, PaymentMethod)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Mark Delivered'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment confirmation'),
              const SizedBox(height: 8),
              DropdownButtonFormField<PaymentStatus>(
                initialValue: selectedStatus,
                items: const [
                  DropdownMenuItem(
                    value: PaymentStatus.done,
                    child: Text('Done'),
                  ),
                  DropdownMenuItem(
                    value: PaymentStatus.pending,
                    child: Text('Remaining'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedStatus = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: selectedMethod,
                items: PaymentMethod.values
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(_paymentMethodLabel(method)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedMethod = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop((selectedStatus, selectedMethod)),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmZeroAmountDelivery(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Amount is 0'),
        content: const Text(
          'This order amount is 0. Do you still want to mark it as delivered?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showZeroAmountPaymentAlert(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Amount is 0'),
        content: const Text(
          'Payment amount is 0. Please set a valid amount before marking payment done.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOrderAction(
    BuildContext context,
    Order order,
    String value,
  ) async {
    final firestore = ref.read(firestoreServiceProvider);
    try {
      if (value == 'approve') {
        if (order.status != OrderStatus.pending) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BusinessOrderDetailScreen(order: order),
          ),
        );
      } else if (value == 'mark_delivered') {
        if (order.status == OrderStatus.pending) return;
        final amount = order.payment.amount ?? 0;
        if (amount.abs() < 0.000001) {
          final shouldContinue = await _confirmZeroAmountDelivery(context);
          if (!shouldContinue) return;
        }
        (PaymentStatus, PaymentMethod)? paymentChoice;
        if (order.payment.status == PaymentStatus.done) {
          paymentChoice = (PaymentStatus.done, order.payment.method);
        } else {
          if (!context.mounted) return;
          paymentChoice = await _askPaymentOnDelivery(context, order);
          if (paymentChoice == null) return;
        }
        await firestore.updateOrder(order.id, {
          'status': enumToString(OrderStatus.completed),
          'delivery': {
            ...order.delivery.toMap(),
            'status': enumToString(DeliveryStatus.delivered),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
            'deliveredAt': Timestamp.fromDate(DateTime.now()),
          },
          'payment': {
            ...order.payment.toMap(),
            'status': enumToString(paymentChoice.$1),
            'method': enumToString(paymentChoice.$2),
            'collectedBy': paymentChoice.$1 == PaymentStatus.done
                ? enumToString(PaymentCollectedBy.businessOwner)
                : null,
            'collectedByName': paymentChoice.$1 == PaymentStatus.done
                ? widget.profile.name
                : null,
            'collectedAt': paymentChoice.$1 == PaymentStatus.done
                ? Timestamp.fromDate(DateTime.now())
                : null,
            'collectionNote': paymentChoice.$1 == PaymentStatus.done
                ? order.payment.collectionNote
                : null,
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          },
        });
      } else if (value == 'payment_done') {
        if (order.status == OrderStatus.pending) return;
        final amount = order.payment.amount ?? 0;
        if (amount.abs() < 0.000001) {
          await _showZeroAmountPaymentAlert(context);
          return;
        }
        if (!context.mounted) return;
        final paymentChoice = await PaymentDialogs.showSetPaymentDoneDialog(
          context,
          initialMethod: order.payment.method,
          initialRemark: order.payment.remark,
        );
        if (paymentChoice == null) return;
        final payment = PaymentInfo(
          status: PaymentStatus.done,
          method: paymentChoice.$1,
          amount: order.payment.amount,
          remark: paymentChoice.$2,
          confirmedByCustomer: order.payment.confirmedByCustomer ?? false,
          collectedBy: PaymentCollectedBy.businessOwner,
          collectedByName: widget.profile.name,
          collectedAt: DateTime.now(),
          collectionNote: order.payment.collectionNote,
          updatedAt: DateTime.now(),
        );
        await firestore.updateOrder(order.id, {'payment': payment.toMap()});
      }
    } catch (e) {
      if (!context.mounted) return;
      final message = e is FirebaseException && e.code == 'permission-denied'
          ? 'Permission denied. Please deploy latest Firestore rules and try again.'
          : 'Failed to update order. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
