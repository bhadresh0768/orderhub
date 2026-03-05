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
    return Card(
      margin: margin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? BorderSide(color: Colors.red.shade400, width: 1.8)
            : BorderSide.none,
      ),
      child: onTap == null
          ? child
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: child,
            ),
    );
  }
}
