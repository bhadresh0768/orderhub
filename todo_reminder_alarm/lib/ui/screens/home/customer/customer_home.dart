import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/models/app_user.dart';
import 'package:todo_reminder_alarm/models/business.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/models/order.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'package:todo_reminder_alarm/ui/screens/catalog/customer_catalog_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/common/order_card_shell.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/common/order_date_range_row.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/common/order_shared_helpers.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/common/order_status_chip.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/create_order_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/customer_order_detail_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/order_history_report_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/profile/profile_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/profile/public_business_profile_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/support/contact_us_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/support/invite_friends_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/support/support_tickets_screen.dart';

part 'customer_home_state.dart';
part 'customer_home_shell.dart';
part 'customer_home_body.dart';
