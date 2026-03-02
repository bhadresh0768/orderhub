part of 'customer_home.dart';

final _customerStoreSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);
final _customerOrderSearchProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);
final _customerCategoryFilterProvider = StateProvider.autoDispose<String>(
  (ref) => 'All',
);
final _customerCityFilterProvider = StateProvider.autoDispose<String>(
  (ref) => 'All',
);
final _customerOrderFilterProvider = StateProvider.autoDispose<String>(
  (ref) => 'All',
);
final _customerOrderDateFilterProvider = StateProvider.autoDispose<_OrderDateFilter>(
  (ref) => _OrderDateFilter.all,
);
final _customerOrderFromDateProvider = StateProvider.autoDispose<DateTime?>(
  (ref) => null,
);
final _customerOrderToDateProvider = StateProvider.autoDispose<DateTime?>(
  (ref) => null,
);

enum _OrderDateFilter { all, today, thisWeek, thisMonth, thisYear, custom }
