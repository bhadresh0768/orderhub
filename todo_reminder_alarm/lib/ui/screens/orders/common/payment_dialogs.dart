import 'package:flutter/material.dart';

import '../../../../models/enums.dart';
import 'order_shared_helpers.dart';

class PaymentDialogs {
  static Future<(PaymentMethod, String?)?> showSetPaymentDoneDialog(
    BuildContext context, {
    required PaymentMethod initialMethod,
    String? initialRemark,
  }) async {
    var selectedMethod = initialMethod;
    var remark = (initialRemark ?? '').trim();
    final result = await showDialog<(PaymentMethod, String?)>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Set Payment Done'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<PaymentMethod>(
                initialValue: selectedMethod,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: PaymentMethod.values
                    .map(
                      (method) => DropdownMenuItem(
                        value: method,
                        child: Text(OrderSharedHelpers.paymentMethodLabel(method)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedMethod = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: remark,
                decoration: const InputDecoration(
                  labelText: 'Payment Remark',
                  hintText: 'Optional note',
                ),
                maxLines: 2,
                onChanged: (value) {
                  remark = value;
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
              onPressed: () {
                final cleaned = remark.trim();
                Navigator.of(
                  context,
                ).pop((selectedMethod, cleaned.isEmpty ? null : cleaned));
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    return result;
  }
}
