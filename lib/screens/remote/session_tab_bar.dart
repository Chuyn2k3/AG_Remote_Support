import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/remote_session.dart';
import '../../core/theme/app_colors.dart';

/// Tab bar kiểu Chrome Mobile cho phép switch giữa nhiều RemoteSession.
class SessionTabBar extends StatelessWidget {
  final List<RemoteSession> sessions;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<int> onTabClosed;
  final VoidCallback onAddTab;
  final bool isSplitScreen;
  final VoidCallback? onToggleSplitScreen;
  final bool isLandscape;
  final VoidCallback? onToggleOrientation;

  const SessionTabBar({
    super.key,
    required this.sessions,
    required this.activeIndex,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onAddTab,
    this.isSplitScreen = false,
    this.onToggleSplitScreen,
    this.isLandscape = false,
    this.onToggleOrientation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          // Scrollable tab list
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isActive = index == activeIndex;
                return _SessionTab(
                  session: session,
                  isActive: isActive,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTabSelected(index);
                  },
                  onClose: sessions.length > 1
                      ? () {
                          HapticFeedback.lightImpact();
                          onTabClosed(index);
                        }
                      : null,
                );
              },
            ),
          ),
          // Nút chia đôi màn hình (Split View)
          if (onToggleSplitScreen != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleSplitScreen!();
              },
              child: Container(
                width: 36,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                decoration: BoxDecoration(
                  color: isSplitScreen
                      ? const Color(0xFF0A84FF).withOpacity(0.3)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: isSplitScreen
                      ? Border.all(color: const Color(0xFF0A84FF), width: 1.2)
                      : null,
                ),
                child: Icon(
                  Icons.splitscreen_rounded,
                  size: 16,
                  color: isSplitScreen ? const Color(0xFF38BDF8) : Colors.white60,
                ),
              ),
            ),
          // Nút xoay ngang / dọc màn hình
          if (onToggleOrientation != null)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleOrientation!();
              },
              child: Container(
                width: 36,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                decoration: BoxDecoration(
                  color: isLandscape
                      ? const Color(0xFF30D158).withOpacity(0.3)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: isLandscape
                      ? Border.all(color: const Color(0xFF30D158), width: 1.2)
                      : null,
                ),
                child: Icon(
                  isLandscape
                      ? Icons.screen_lock_landscape_rounded
                      : Icons.screen_rotation_rounded,
                  size: 16,
                  color: isLandscape ? const Color(0xFF30D158) : Colors.white60,
                ),
              ),
            ),
          // Nút thêm tab (+)
          if (sessions.length < 4)
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onAddTab();
              },
              child: Container(
                width: 36,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_rounded, size: 18, color: Colors.white60),
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  final RemoteSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _SessionTab({
    required this.session,
    required this.isActive,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minWidth: 80, maxWidth: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF0A84FF).withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF0A84FF).withOpacity(0.5)
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status dot
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: session.isDisconnected
                    ? const Color(0xFFFF3B30)  // iOS red
                    : AppColors.statusSuccess,
                shape: BoxShape.circle,
              ),
            ),
            // Session title
            Flexible(
              child: Text(
                session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? Colors.white : Colors.white60,
                ),
              ),
            ),
            // Nút đóng tab
            if (onClose != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: isActive ? Colors.white70 : Colors.white30,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
