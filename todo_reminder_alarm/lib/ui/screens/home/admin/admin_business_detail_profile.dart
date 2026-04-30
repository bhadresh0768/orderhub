part of 'admin_business_detail_screen.dart';

extension _AdminBusinessDetailProfile on AdminBusinessDetailScreen {
  Widget _buildBusinessProfileCard(
    BuildContext context,
    WidgetRef ref,
    BusinessProfile business,
    AsyncValue<AppUser?> ownerAsync,
    int totalOrders,
    int filteredOrders,
    int pendingCount,
    int processingCount,
    int completedCount,
  ) {
    final expanded = ref.watch(_adminBusinessProfileExpandedProvider(business.id));
    final owner = ownerAsync.asData?.value;
    final ownerName = (owner?.name.trim().isNotEmpty ?? false)
        ? owner!.name.trim()
        : '-';
    final ownerPhone = (owner?.phoneNumber?.trim().isNotEmpty ?? false)
        ? owner!.phoneNumber!.trim()
        : '-';
    final ownerEmail = (owner?.email.trim().isNotEmpty ?? false)
        ? owner!.email.trim()
        : '-';
    final businessPhone = (business.phone ?? '').trim().isEmpty
        ? '-'
        : business.phone!.trim();
    final businessUnique = (business.gstNumber ?? '').trim().isEmpty
        ? '-'
        : business.gstNumber!.trim();
    final ownerActionPhone = ownerPhone == '-' ? null : ownerPhone;
    final businessActionPhone = businessPhone == '-' ? null : businessPhone;
    final fields = <_BusinessInfoField>[
      _BusinessInfoField(label: 'Owner Name', value: ownerName),
      _BusinessInfoField(
        label: 'Owner Mobile',
        value: ownerPhone,
        actionPhone: ownerActionPhone,
      ),
      _BusinessInfoField(label: 'Owner Email', value: ownerEmail),
      _BusinessInfoField(
        label: 'Owner Registration Date',
        value: owner?.createdAt == null ? '-' : _formatDateTime(owner!.createdAt!),
      ),
      _BusinessInfoField(label: 'Business Name', value: business.name),
      _BusinessInfoField(label: 'Category', value: business.category),
      _BusinessInfoField(
        label: 'City',
        value: business.city.isEmpty ? '-' : business.city,
      ),
      _BusinessInfoField(
        label: 'Address',
        value: (business.address ?? '').trim().isEmpty
            ? '-'
            : business.address!.trim(),
      ),
      _BusinessInfoField(
        label: 'Business Mobile',
        value: businessPhone,
        actionPhone: businessActionPhone,
      ),
      _BusinessInfoField(label: 'Business Unique No', value: businessUnique),
      _BusinessInfoField(label: 'Status', value: _capitalize(business.status.name)),
      _BusinessInfoField(
        label: 'Business Registration Date',
        value: business.createdAt == null ? '-' : _formatDateTime(business.createdAt!),
      ),
      _BusinessInfoField(label: 'Total Orders', value: '$totalOrders'),
      _BusinessInfoField(label: 'Filtered Orders', value: '$filteredOrders'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBusinessLogoFor(business),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    business.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${business.category} • ${business.city}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pending: $pendingCount • Processing: $processingCount • Completed: $completedCount',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            ref.read(_adminBusinessProfileExpandedProvider(business.id).notifier).state =
                !expanded;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  'Business Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  expanded ? 'Collapse' : 'Expand',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
                const SizedBox(width: 4),
                Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildInfoGrid(context, fields),
          ),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ],
    );
  }

  Widget _buildBusinessLogoFor(BusinessProfile business) {
    final logo = business.logoUrl?.trim();
    final hasLogo = logo != null && logo.isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 72,
        color: Colors.black12,
        child: hasLogo
            ? Image.network(
                logo,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) =>
                    const Icon(Icons.storefront, size: 34),
              )
            : const Icon(Icons.storefront, size: 34),
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, List<_BusinessInfoField> fields) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final itemWidth = isWide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map(
                (field) => SizedBox(
                  width: itemWidth,
                  child: _infoTile(
                    context,
                    field.label,
                    field.value,
                    actionPhone: field.actionPhone,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _infoTile(
    BuildContext context,
    String label,
    String value, {
    String? actionPhone,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            Row(
              children: [
                Expanded(
                  child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
                ),
                if (actionPhone != null) ...[
                  IconButton(
                    tooltip: 'Call',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.call_outlined),
                    onPressed: () => ContactActions.callPhone(context, actionPhone),
                  ),
                  IconButton(
                    tooltip: 'WhatsApp',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.chat_bubble_outline),
                    onPressed: () =>
                        ContactActions.openWhatsApp(context, actionPhone),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
