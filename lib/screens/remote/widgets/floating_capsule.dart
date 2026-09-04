import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class FloatingCapsule extends StatefulWidget {
  final bool isWakelockEnabled;
  final VoidCallback onToggleWakelock;
  final VoidCallback onReload;
  final VoidCallback onExit;
  final VoidCallback onCopyUrl;
  final VoidCallback onAccount;

  const FloatingCapsule({
    super.key,
    required this.isWakelockEnabled,
    required this.onToggleWakelock,
    required this.onReload,
    required this.onExit,
    required this.onCopyUrl,
    required this.onAccount,
  });

  @override
  State<FloatingCapsule> createState() => _FloatingCapsuleState();
}

class _FloatingCapsuleState extends State<FloatingCapsule> {
  bool _isMini = false;
  Offset _offset = const Offset(20, 80);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _offset.dx.clamp(10.0, screenSize.width - (_isMini ? 60.0 : 330.0)),
      top: _offset.dy.clamp(50.0, screenSize.height - 120.0),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
          });
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_isMini ? 20 : 30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: EdgeInsets.symmetric(
                horizontal: _isMini ? 8 : 12,
                vertical: _isMini ? 8 : 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark.withOpacity(0.85),
                borderRadius: BorderRadius.circular(_isMini ? 20 : 30),
                border: Border.all(
                  color: AppColors.brandPrimary.withOpacity(0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isMini ? _buildMiniView() : _buildExpandedView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniView() {
    return InkWell(
      onTap: () => setState(() => _isMini = false),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: const Icon(
          Icons.rocket_launch,
          size: 20,
          color: AppColors.brandPrimary,
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Keep Awake Toggle
        _buildActionButton(
          icon: widget.isWakelockEnabled ? Icons.lightbulb : Icons.lightbulb_outline,
          label: 'Sáng',
          color: widget.isWakelockEnabled ? AppColors.stateWarning : AppColors.textPrimary,
          onTap: widget.onToggleWakelock,
        ),
        _buildDivider(),
        // Account / Google multi-account
        _buildActionButton(
          icon: Icons.account_circle_outlined,
          label: 'Tài khoản',
          color: AppColors.brandPrimaryLight,
          onTap: widget.onAccount,
        ),
        _buildDivider(),
        // Reload Button
        _buildActionButton(
          icon: Icons.refresh,
          label: 'Tải lại',
          onTap: widget.onReload,
        ),
        _buildDivider(),
        // Copy URL
        _buildActionButton(
          icon: Icons.copy,
          label: 'Copy',
          onTap: widget.onCopyUrl,
        ),
        _buildDivider(),
        // Exit to Hub
        _buildActionButton(
          icon: Icons.home_outlined,
          label: 'Hub',
          onTap: widget.onExit,
        ),
        _buildDivider(),
        // Minimize Button
        IconButton(
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(6),
          icon: const Icon(Icons.remove, size: 16, color: AppColors.textMuted),
          onPressed: () => setState(() => _isMini = true),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? AppColors.textPrimary),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color ?? AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 20,
      width: 1,
      color: AppColors.borderSubtle,
      margin: const EdgeInsets.symmetric(horizontal: 3),
    );
  }
}
