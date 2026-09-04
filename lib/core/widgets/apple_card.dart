import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final BorderSide? border;

  const AppleCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final defaultBorderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final cardWidget = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.fromBorderSide(
          border ?? BorderSide(color: defaultBorderColor, width: 1),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: cardWidget,
        ),
      );
    }

    return cardWidget;
  }
}
