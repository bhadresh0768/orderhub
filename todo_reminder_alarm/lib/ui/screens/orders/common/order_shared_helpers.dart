import 'package:flutter/material.dart';

import '../../../../models/enums.dart';
import '../../../../models/order.dart';

/// Shared order UI/data helpers reused by multiple order screens.
enum OrderDateFilterOption { all, today, thisWeek, thisMonth, thisYear, custom }

class OrderSharedHelpers {
  static String capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  static String formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  static String formatDateTime(DateTime date) {
    final local = date.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString();
    final hour24 = local.hour;
    final hour12 = hour24 == 0
        ? 12
        : (hour24 > 12 ? hour24 - 12 : hour24);
    final hh = hour12.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final meridiem = hour24 >= 12 ? 'PM' : 'AM';
    return '$dd/$mm/$yyyy $hh:$min $meridiem';
  }

  static String formatDateTimeOrDash(DateTime? date) {
    if (date == null) return '-';
    return formatDateTime(date);
  }

  static bool isInDateRange(DateTime date, DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final endExclusive = DateTime(
      to.year,
      to.month,
      to.day,
    ).add(const Duration(days: 1));
    return !date.isBefore(start) && date.isBefore(endExclusive);
  }

  static bool matchesDateFilter(
    DateTime date,
    OrderDateFilterOption filter,
    DateTime now, {
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    switch (filter) {
      case OrderDateFilterOption.all:
        return true;
      case OrderDateFilterOption.today:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case OrderDateFilterOption.thisWeek:
        final startOfToday = DateTime(now.year, now.month, now.day);
        final startOfWeek = startOfToday.subtract(
          Duration(days: now.weekday - 1),
        );
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return !date.isBefore(startOfWeek) && date.isBefore(endOfWeek);
      case OrderDateFilterOption.thisMonth:
        return date.year == now.year && date.month == now.month;
      case OrderDateFilterOption.thisYear:
        return date.year == now.year;
      case OrderDateFilterOption.custom:
        if (customFrom == null || customTo == null) return false;
        return isInDateRange(date, customFrom, customTo);
    }
  }

  static String dateFilterLabel(OrderDateFilterOption filter) {
    return switch (filter) {
      OrderDateFilterOption.all => 'All',
      OrderDateFilterOption.today => 'Today',
      OrderDateFilterOption.thisWeek => 'This Week',
      OrderDateFilterOption.thisMonth => 'This Month',
      OrderDateFilterOption.thisYear => 'This Year',
      OrderDateFilterOption.custom => 'Custom Range',
    };
  }

  static OrderStatus effectiveStatus(
    Order order, {
    bool normalizeApprovedToInProgress = false,
  }) {
    if (order.delivery.status == DeliveryStatus.delivered) {
      return OrderStatus.completed;
    }
    if (normalizeApprovedToInProgress && order.status == OrderStatus.approved) {
      return OrderStatus.inProgress;
    }
    return order.status;
  }

  static Color statusColor(OrderStatus status) {
    return switch (status) {
      OrderStatus.completed => Colors.green,
      OrderStatus.pending => Colors.red,
      OrderStatus.approved || OrderStatus.inProgress => Colors.yellow.shade800,
      OrderStatus.cancelled => Colors.grey,
    };
  }

  static String statusLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'Pending',
      OrderStatus.approved || OrderStatus.inProgress => 'Processing',
      OrderStatus.completed => 'Completed',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  static String paymentStatusLabel(PaymentStatus status) {
    return status == PaymentStatus.done ? 'Done' : 'Remaining';
  }

  static String paymentMethodLabel(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.check => 'Check',
      PaymentMethod.onlineTransfer => 'Online Transfer',
    };
  }

  static String amountLabel(double? value) {
    if (value == null) return 'Not set';
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }
}
