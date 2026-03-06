import 'package:flutter/material.dart';

class OrderCardShell extends StatelessWidget {
  const OrderCardShell({
    super.key,
    required this.child,
    this.onTap,
    this.isHighlighted = false,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool isHighlighted;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final borderColor = isHighlighted
        ? const Color(0xFFE2634D)
        : const Color(0xFFE7EBF0);
    return Card(
      margin: margin,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: isHighlighted ? 1.4 : 1),
      ),
      child: onTap == null
          ? child
          : InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: child,
            ),
    );
  }
}
