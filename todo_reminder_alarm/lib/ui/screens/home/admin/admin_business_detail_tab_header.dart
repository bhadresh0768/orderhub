part of 'admin_business_detail_screen.dart';

class _AdminTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _AdminTabBarHeaderDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _AdminTabBarHeaderDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
