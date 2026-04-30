part of 'admin_business_detail_screen.dart';

extension _AdminBusinessDetailTabs on AdminBusinessDetailScreen {
  Widget _buildOrdersTab(
    BuildContext context,
    WidgetRef ref,
    List<Order> filteredOrders,
    _AdminBusinessDateFilter dateFilter,
    DateTime? fromDate,
    DateTime? toDate,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<OrderStatus?>(
                initialValue: ref.watch(
                  _adminBusinessStatusFilterProvider(business.id),
                ),
                decoration: const InputDecoration(labelText: 'Status Filter'),
                items: [
                  const DropdownMenuItem<OrderStatus?>(
                    value: null,
                    child: Text('All'),
                  ),
                  ...OrderStatus.values.map(
                    (status) => DropdownMenuItem<OrderStatus?>(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  ),
                ],
                onChanged: (value) {
                  ref
                          .read(
                            _adminBusinessStatusFilterProvider(
                              business.id,
                            ).notifier,
                          )
                          .state =
                      value;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<_AdminBusinessDateFilter>(
                initialValue: dateFilter,
                decoration: const InputDecoration(labelText: 'Date Filter'),
                items: _AdminBusinessDateFilter.values
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(_dateFilterLabel(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  ref
                          .read(
                            _adminBusinessDateFilterProvider(
                              business.id,
                            ).notifier,
                          )
                          .state =
                      value;
                  if (value != _AdminBusinessDateFilter.custom) {
                    ref
                            .read(
                              _adminBusinessFromDateProvider(
                                business.id,
                              ).notifier,
                            )
                            .state =
                        null;
                    ref
                            .read(
                              _adminBusinessToDateProvider(
                                business.id,
                              ).notifier,
                            )
                            .state =
                        null;
                  } else if (fromDate == null || toDate == null) {
                    _pickCustomRange(context, ref);
                  }
                },
              ),
            ),
          ],
        ),
        if (dateFilter == _AdminBusinessDateFilter.custom) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  (fromDate != null && toDate != null)
                      ? '${_formatDate(fromDate)} to ${_formatDate(toDate)}'
                      : 'No custom range selected',
                ),
              ),
              TextButton(
                onPressed: () => _pickCustomRange(context, ref),
                child: const Text('Select'),
              ),
              TextButton(
                onPressed: () {
                  ref
                          .read(
                            _adminBusinessFromDateProvider(
                              business.id,
                            ).notifier,
                          )
                          .state =
                      null;
                  ref
                          .read(
                            _adminBusinessToDateProvider(business.id).notifier,
                          )
                          .state =
                      null;
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        if (filteredOrders.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('No orders match current filters.'),
            ),
          ),
        ...filteredOrders.map((order) {
          final effectiveStatus = OrderSharedHelpers.effectiveStatus(order);
          final statusColor = OrderSharedHelpers.statusColor(effectiveStatus);
          return Card(
            child: ListTile(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerOrderDetailScreen(order: order),
                  ),
                );
              },
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Order ${order.displayOrderNumber} • '),
                    TextSpan(
                      text: _statusLabel(effectiveStatus),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              subtitle: Text(
                'Order by: ${order.customerName}\n'
                'Payment: ${_capitalize(order.payment.status.name)} • Delivery: ${_capitalize(order.delivery.status.name)}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAgentsTab(AsyncValue<List<DeliveryAgent>> agentsAsync) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        agentsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Error: $err'),
            ),
          ),
          data: (agents) {
            if (agents.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No delivery agents found for this business.'),
                ),
              );
            }
            return Column(
              children: agents
                  .map<Widget>(
                    (agent) => Card(
                      child: ListTile(
                        title: Text(agent.name),
                        subtitle: Text(
                          '${agent.phone}\nStatus: ${agent.isActive ? 'Active' : 'Inactive'}',
                        ),
                        isThreeLine: true,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
