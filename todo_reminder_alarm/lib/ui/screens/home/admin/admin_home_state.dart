import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/models/enums.dart';

final adminSearchProvider = StateProvider.autoDispose.family<String, String>(
  (ref, _) => '',
);

final adminTicketStatusProvider = StateProvider<SupportTicketStatus?>(
  (ref) => null,
);

final adminOrderDateFilterProvider = StateProvider.autoDispose<AdminOrderDateFilter>(
  (ref) => AdminOrderDateFilter.all,
);

final adminOrderFromDateProvider = StateProvider.autoDispose<DateTime?>(
  (ref) => null,
);

final adminOrderToDateProvider = StateProvider.autoDispose<DateTime?>(
  (ref) => null,
);

enum AdminOrderDateFilter { all, today, thisWeek, thisMonth, thisYear, custom }
