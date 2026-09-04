import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Offset _offset = const Offset(16, 70);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _offset.dx.clamp(10.0, screenSize.width - (_isMini ? 55.0 : 330.0)),
      top: _offset.dy.clamp(44.0, screenSize.height - 110.0),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _offset += details.delta;
          });
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_isMini ? 20 : 26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: _isMini ? 8 : 10,
                vertical: _isMini ? 6 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E).withOpacity(0.82),
                borderRadius: BorderRadius.circular(_isMini ? 20 : 26),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
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
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isMini = false);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.statusSuccess,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.touch_app_rounded,
              size: 16,
              color: Colors.white70,
            ),
          ],
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
          icon: widget.isWakelockEnabled ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded,
          label: 'Sáng',
          color: widget.isWakelockEnabled ? AppColors.statusWarning : Colors.white,
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onToggleWakelock();
          },
        ),
        _buildDivider(),
        // Multi-account modal
        _buildActionButton(
          icon: Icons.person_outline_rounded,
          label: 'Tài khoản',
          color: const Color(0xFF0A84FF),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onAccount();
          },
        ),
        _buildDivider(),
        // Reload
        _buildActionButton(
          icon: Icons.refresh_rounded,
          label: 'Tải lại',
          color: Colors.white,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onReload();
          },
        ),
        _buildDivider(),
        // Copy URL
        _buildActionButton(
          icon: Icons.copy_rounded,
          label: 'Copy',
          color: Colors.white,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onCopyUrl();
          },
        ),
        _buildDivider(),
        // Exit to Hub
        _buildActionButton(
          icon: Icons.home_rounded,
          label: 'Hub',
          color: Colors.white,
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onExit();
          },
        ),
        _buildDivider(),
        // Minimize Button
        IconButton(
          tooltip: 'Thu gọn',
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.all(6),
          icon: const Icon(Icons.close_fullscreen_rounded, size: 15, color: Colors.white54),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _isMini = true);
          },
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
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color ?? Colors.white),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color ?? Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 18,
      width: 0.8,
      color: Colors.white.withOpacity(0.14),
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}
