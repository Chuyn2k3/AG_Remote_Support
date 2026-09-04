import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

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
    final cardWidget = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.fromBorderSide(
          border ?? const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}
