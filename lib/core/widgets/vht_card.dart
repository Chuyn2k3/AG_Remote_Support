import 'package:flutter/material.dart';
import 'apple_card.dart';

class VhtCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BorderSide? border;

  const VhtCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return AppleCard(
      padding: padding,
      onTap: onTap,
      border: border,
      child: child,
    );
  }
}
