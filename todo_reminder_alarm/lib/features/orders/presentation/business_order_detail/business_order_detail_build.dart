part of 'business_order_detail_screen.dart';

extension _BusinessOrderDetailBuild on _BusinessOrderDetailScreenState {
  Widget _buildContent(BuildContext context) {
    ref.watch(_businessOrderUiProvider(widget.order));
    final agentsAsync = ref.watch(
      deliveryAgentsForBusinessProvider(_order.businessId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Order ${_order.displayOrderNumber} Details'),
        actions: [
          IconButton(
            tooltip: 'Share order details',
            onPressed: _shareOrderDetails,
            icon: const Icon(Icons.share_outlined),
          ),
          if (_isLocked)
            IconButton(
              tooltip: 'Download Bill',
              onPressed: _downloadBill,
              icon: const Icon(Icons.download_outlined),
            ),
          if (_isLocked)
            IconButton(
              tooltip: 'Print / Share Bill',
              onPressed: _printOrShareBill,
              icon: const Icon(Icons.print_outlined),
            ),
          IconButton(
            tooltip: 'Share on WhatsApp',
            onPressed: _shareOrderDetailsOnWhatsApp,
            icon: ClipOval(
              child: Image.asset(
                'assets/images/whatsapp_share.png',
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.chat, color: Colors.green),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildOrderSummaryCard(context),
            const SizedBox(height: 12),
            _buildItemPricingCard(context),
            const SizedBox(height: 12),
            _buildQuickStatusCard(context, agentsAsync),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: Colors.black54);
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500, height: 1.25);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text('$label:', style: labelStyle)),
          Expanded(
            child: Text(
              value,
              style: valueStyle?.copyWith(
                color: valueColor,
                fontWeight: valueWeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
