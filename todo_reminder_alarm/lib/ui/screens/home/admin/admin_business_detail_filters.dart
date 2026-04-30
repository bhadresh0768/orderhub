part of 'admin_business_detail_screen.dart';

extension _AdminBusinessDetailFilters on AdminBusinessDetailScreen {
  String _statusLabel(OrderStatus status) {
    return switch (status) {
      OrderStatus.pending => 'Pending',
      OrderStatus.approved || OrderStatus.inProgress => 'Processing',
      OrderStatus.completed => 'Completed',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  String _dateFilterLabel(_AdminBusinessDateFilter filter) {
    return switch (filter) {
      _AdminBusinessDateFilter.all => 'All',
      _AdminBusinessDateFilter.today => 'Today',
      _AdminBusinessDateFilter.thisWeek => 'This Week',
      _AdminBusinessDateFilter.thisMonth => 'This Month',
      _AdminBusinessDateFilter.thisYear => 'This Year',
      _AdminBusinessDateFilter.custom => 'Custom Range',
    };
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  String _formatDateTime(DateTime date) {
    final d = date.toLocal();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$month-$day $hour:$minute';
  }

  bool _isInDateRange(DateTime date, DateTime from, DateTime to) {
    final local = date.toLocal();
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return !local.isBefore(start) && !local.isAfter(end);
  }

  bool _matchesDateFilter(
    Order order,
    _AdminBusinessDateFilter filter,
    DateTime? from,
    DateTime? to,
  ) {
    final date = order.createdAt ?? order.updatedAt;
    if (date == null) return filter == _AdminBusinessDateFilter.all;
    final now = DateTime.now();
    final local = date.toLocal();
    switch (filter) {
      case _AdminBusinessDateFilter.all:
        return true;
      case _AdminBusinessDateFilter.today:
        return local.year == now.year &&
            local.month == now.month &&
            local.day == now.day;
      case _AdminBusinessDateFilter.thisWeek:
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
        return !local.isBefore(start) && !local.isAfter(end);
      case _AdminBusinessDateFilter.thisMonth:
        return local.year == now.year && local.month == now.month;
      case _AdminBusinessDateFilter.thisYear:
        return local.year == now.year;
      case _AdminBusinessDateFilter.custom:
        if (from == null || to == null) return false;
        return _isInDateRange(local, from, to);
    }
  }

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final from = ref.read(_adminBusinessFromDateProvider(business.id));
    final to = ref.read(_adminBusinessToDateProvider(business.id));
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: (from != null && to != null)
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (picked == null) return;
    ref.read(_adminBusinessDateFilterProvider(business.id).notifier).state =
        _AdminBusinessDateFilter.custom;
    ref.read(_adminBusinessFromDateProvider(business.id).notifier).state =
        picked.start;
    ref.read(_adminBusinessToDateProvider(business.id).notifier).state =
        picked.end;
  }
}
