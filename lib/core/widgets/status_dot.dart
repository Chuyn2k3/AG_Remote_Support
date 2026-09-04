import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatusDot extends StatelessWidget {
  final bool isOnline;
  final double size;

  const StatusDot({
    super.key,
    required this.isOnline,
    this.size = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.stateSuccess : AppColors.stateNeutral;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: isOnline
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
