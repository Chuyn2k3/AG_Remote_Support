import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusDot extends StatelessWidget {
  final bool isOnline;
  final double size;
  final Color? customColor;

  const StatusDot({
    super.key,
    required this.isOnline,
    this.size = 8.0,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = customColor ?? (isOnline ? AppColors.stateSuccess : AppColors.stateNeutral);
    final hasGlow = isOnline || customColor != null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
    );
  }
}
