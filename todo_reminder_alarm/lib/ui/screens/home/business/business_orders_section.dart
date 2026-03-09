part of 'business_home.dart';

class _BusinessOrdersSection extends StatelessWidget {
  const _BusinessOrdersSection({required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Processing'),
              Tab(text: 'Completed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _BusinessOrdersTab(
                  profile: profile,
                  emptyMessage: 'No new incoming orders.',
                  allowedStatuses: const [OrderStatus.pending],
                  allowActions: true,
                ),
                _BusinessOrdersTab(
                  profile: profile,
                  emptyMessage: 'No processing orders.',
                  allowedStatuses: const [OrderStatus.inProgress],
                  allowActions: true,
                ),
                _BusinessOrdersTab(
                  profile: profile,
                  emptyMessage: 'No completed orders.',
                  allowedStatuses: const [OrderStatus.completed],
                  allowActions: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
