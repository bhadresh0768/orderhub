import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import 'package:todo_reminder_alarm/models/app_user.dart';
import 'package:todo_reminder_alarm/models/business.dart';
import 'package:todo_reminder_alarm/models/enums.dart';
import 'package:todo_reminder_alarm/models/order.dart';
import 'package:todo_reminder_alarm/providers.dart';
import 'package:todo_reminder_alarm/features/profile/presentation/profile_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/support/contact_us_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/support/invite_friends_screen.dart';
import 'package:todo_reminder_alarm/ui/screens/support/privacy_policy_screen.dart';

part 'delivery_boy_home_drawer.dart';
part 'delivery_boy_home_actions.dart';
part 'delivery_boy_home_orders_list.dart';

enum _DeliveryDateFilter { today, week, month, year, custom }

final _deliveryBoyUiProvider = StateProvider.autoDispose<_DeliveryBoyUiState>(
  (ref) => const _DeliveryBoyUiState(),
);

class _DeliveryBoyUiState {
  const _DeliveryBoyUiState({
    this.filter = _DeliveryDateFilter.month,
    this.customFrom,
    this.customTo,
  });

  final _DeliveryDateFilter filter;
  final DateTime? customFrom;
  final DateTime? customTo;

  _DeliveryBoyUiState copyWith({
    _DeliveryDateFilter? filter,
    Object? customFrom = _deliveryDateUnset,
    Object? customTo = _deliveryDateUnset,
  }) {
    return _DeliveryBoyUiState(
      filter: filter ?? this.filter,
      customFrom: customFrom == _deliveryDateUnset
          ? this.customFrom
          : customFrom as DateTime?,
      customTo: customTo == _deliveryDateUnset
          ? this.customTo
          : customTo as DateTime?,
    );
  }
}

const _deliveryDateUnset = Object();

class DeliveryBoyHomeScreen extends ConsumerWidget {
  const DeliveryBoyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).value;
    if (authUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profileAsync = ref.watch(userProfileProvider(authUser.uid));
    return profileAsync.when(
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('No profile found')));
        }
        final phone = (profile.phoneNumber ?? '').trim();
        if (phone.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Delivery Dashboard')),
            drawer: _buildDrawer(context, ref, profile),
            body: const Center(
              child: Text('Phone number missing in profile. Contact admin.'),
            ),
          );
        }
        return _DeliveryBoyBody(
          profile: profile,
          phone: phone,
          name: profile.name,
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: Center(child: Text('Something went wrong. Please retry.')),
      ),
    );
  }
}

class _DeliveryBoyBody extends ConsumerStatefulWidget {
  const _DeliveryBoyBody({
    required this.profile,
    required this.phone,
    required this.name,
  });

  final AppUser profile;
  final String phone;
  final String name;

  @override
  ConsumerState<_DeliveryBoyBody> createState() => _DeliveryBoyBodyState();
}

class _DeliveryBoyBodyState extends ConsumerState<_DeliveryBoyBody> {
  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(_deliveryBoyUiProvider);
    final ordersAsync = ref.watch(
      ordersForDeliveryAgentByPhoneProvider(widget.phone),
    );
    final businessesAsync = ref.watch(businessesProvider);
    final businessAddressById = <String, String>{};
    final businessList = businessesAsync.asData?.value ?? const <BusinessProfile>[];
    for (final business in businessList) {
      final address = (business.address ?? '').trim();
      final city = business.city.trim();
      final text = address.isEmpty
          ? (city.isEmpty ? '-' : city)
          : (city.isEmpty ? address : '$address, $city');
      businessAddressById[business.id] = text;
    }

    return Scaffold(
      appBar: AppBar(title: Text('Delivery Dashboard • ${widget.name}')),
      drawer: _buildDrawer(context, ref, widget.profile),
      body: ordersAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No deliveries assigned.'));
          }

          final upcomingOrders = orders
              .where((order) => order.delivery.status != DeliveryStatus.delivered)
              .toList();
          final completedOrders = orders
              .where((order) => order.delivery.status == DeliveryStatus.delivered)
              .where((order) => _matchesRange(order, completedTab: true))
              .toList();

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Upcoming Delivery'),
                    Tab(text: 'Completed Delivery'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOrdersList(
                        context,
                        upcomingOrders,
                        businessAddressById: businessAddressById,
                        allowActions: true,
                        emptyText: 'No upcoming deliveries.',
                      ),
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<_DeliveryDateFilter>(
                                    initialValue: uiState.filter,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Filter',
                                    ),
                                    items: _DeliveryDateFilter.values
                                        .map(
                                          (value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(_filterLabel(value)),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        ref.read(_deliveryBoyUiProvider.notifier).state =
                                            uiState.copyWith(filter: value);
                                        if (value == _DeliveryDateFilter.custom &&
                                            (uiState.customFrom == null ||
                                                uiState.customTo == null)) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            _pickCustomRange(
                                              ref.read(_deliveryBoyUiProvider),
                                            );
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (uiState.filter == _DeliveryDateFilter.custom)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (uiState.customFrom != null &&
                                              uiState.customTo != null)
                                          ? '${_formatDate(uiState.customFrom!)} to ${_formatDate(uiState.customTo!)}'
                                          : 'No date range selected',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _pickCustomRange(uiState),
                                    child: const Text('Select'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      ref.read(_deliveryBoyUiProvider.notifier).state =
                                          uiState.copyWith(
                                        customFrom: null,
                                        customTo: null,
                                      );
                                    },
                                    child: const Text('Clear'),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: _buildOrdersList(
                              context,
                              completedOrders,
                              businessAddressById: businessAddressById,
                              allowActions: false,
                              emptyText: 'No completed deliveries in this range.',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Something went wrong. Please retry.')),
      ),
    );
  }
}
