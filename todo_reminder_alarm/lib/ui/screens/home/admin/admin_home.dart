import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:todo_reminder_alarm/providers.dart';
import 'admin_contact_us_tab.dart';
import 'admin_businesses_tab.dart';
import 'admin_orders_tab.dart';
import 'admin_settings_screen.dart';
import 'admin_support_tickets_tab.dart';
import 'admin_users_tab.dart';
import 'package:todo_reminder_alarm/ui/screens/orders/order_history_report_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/profile/profile_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/support/support_tickets_screen.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider).value;
    final profile = authState == null
        ? null
        : ref.watch(userProfileProvider(authState.uid)).value;
    final allOrders = ref.watch(allOrdersProvider).value ?? [];
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Users'),
              Tab(text: 'Businesses'),
              Tab(text: 'Orders'),
              Tab(text: 'Support'),
              Tab(text: 'Contact Us'),
            ],
          ),
        ),
        drawer: Drawer(
          child: SafeArea(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('Menu', style: TextStyle(fontSize: 24)),
                ),
                const Divider(height: 1),
                if (profile != null)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profile'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(user: profile),
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.assessment_outlined),
                  title: const Text('Report & History'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderHistoryReportScreen(
                          title: 'Admin History & Reports',
                          orders: allOrders,
                        ),
                      ),
                    );
                  },
                ),
                if (profile != null)
                  ListTile(
                    leading: const Icon(Icons.support_agent),
                    title: const Text('Help & Support'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SupportTicketsScreen(user: profile),
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Settings'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminSettingsScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Logout'),
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(authServiceProvider).signOut();
                  },
                ),
              ],
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            AdminUsersTab(),
            AdminBusinessesTab(),
            AdminOrdersTab(),
            AdminSupportTicketsTab(),
            AdminContactUsTab(),
          ],
        ),
      ),
    );
  }
}
