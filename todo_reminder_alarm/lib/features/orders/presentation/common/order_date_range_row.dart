import 'package:flutter/material.dart';

import 'order_shared_helpers.dart';

class OrderDateRangeRow extends StatelessWidget {
  const OrderDateRangeRow({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.onSelect,
    required this.onClear,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final VoidCallback onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            (fromDate != null && toDate != null)
                ? '${OrderSharedHelpers.formatDate(fromDate!)} to ${OrderSharedHelpers.formatDate(toDate!)}'
                : 'No date range selected',
          ),
        ),
        TextButton(onPressed: onSelect, child: const Text('Select')),
        TextButton(onPressed: onClear, child: const Text('Clear')),
      ],
    );
  }
}
