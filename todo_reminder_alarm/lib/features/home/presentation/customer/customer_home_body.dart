part of 'customer_home.dart';

class _CustomerHomeBodyState extends ConsumerState<_CustomerHomeBody> {
  @override
  Widget build(BuildContext context) {
    // Show only approved stores; search/filters are applied client-side.
    final businessesAsync = ref.watch(approvedBusinessesProvider);
    final ordersAsync = ref.watch(ordersForCustomerProvider(widget.profile.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: _buildDrawer(ordersAsync.value ?? const []),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Stores'),
                Tab(text: 'My Orders'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Builder(
                    builder: (tabContext) => _buildStoresTab(
                      businessesAsync,
                      DefaultTabController.of(tabContext),
                    ),
                  ),
                  _buildOrdersTab(ordersAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
