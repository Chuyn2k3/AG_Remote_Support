import 'dart:math' as math;
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
  final VoidCallback? onVoicePrompt;
  final VoidCallback? onGitActions;
  final VoidCallback? onBubble;
  final bool bubbleActive;
  final VoidCallback? onToggleSplit;
  final bool isSplitActive;
  final VoidCallback? onToggleOrientation;
  final bool isLandscape;

  const FloatingCapsule({
    super.key,
    required this.isWakelockEnabled,
    required this.onToggleWakelock,
    required this.onReload,
    required this.onExit,
    required this.onCopyUrl,
    required this.onAccount,
    this.onVoicePrompt,
    this.onGitActions,
    this.onBubble,
    this.bubbleActive = false,
    this.onToggleSplit,
    this.isSplitActive = false,
    this.onToggleOrientation,
    this.isLandscape = false,
  });

  @override
  State<FloatingCapsule> createState() => _FloatingCapsuleState();
}

class _FloatingCapsuleState extends State<FloatingCapsule> {
  bool _isMini = false;
  bool _showMore = false;
  Offset _offset = const Offset(16, 70);

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final maxLeft = math.max(10.0, screenSize.width - (_isMini ? 95.0 : 345.0));
    final maxTop = math.max(topPadding + 10.0, screenSize.height - 140.0);
    final safeLeft = _offset.dx.clamp(10.0, maxLeft);
    final safeTop = _offset.dy.clamp(topPadding + 6.0, maxTop);

    return Positioned(
      left: safeLeft,
      top: safeTop,
      child: RepaintBoundary(
        child: GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _offset += details.delta;
            });
          },
          onDoubleTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _isMini = !_isMini;
              if (_isMini) _showMore = false;
            });
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: _isMini ? 6 : 6,
                  vertical: _isMini ? 4 : 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16161A).withOpacity(0.96),
                  borderRadius: BorderRadius.circular(_isMini ? 20 : 24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _isMini ? _buildMiniView() : _buildExpandedView(),
              ),
              if (!_isMini && _showMore) ...[
                const SizedBox(height: 6),
                _buildMoreMenu(),
              ],
            ],
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.statusSuccess,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.statusSuccess.withOpacity(0.7),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.terminal_rounded,
              size: 15,
              color: Color(0xFF0A84FF),
            ),
            if (widget.isWakelockEnabled) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.lightbulb_rounded,
                size: 13,
                color: Color(0xFFFFD60A),
              ),
            ],
            if (widget.bubbleActive) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.bubble_chart_rounded,
                size: 13,
                color: Color(0xFFFF9F0A),
              ),
            ],
            const SizedBox(width: 6),
            const Icon(
              Icons.unfold_more_rounded,
              size: 14,
              color: Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grip Handle
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 16,
              color: Colors.white24,
            ),
          ),
          const SizedBox(width: 2),

          // Primary: Voice Prompt
          if (widget.onVoicePrompt != null) ...[
            _buildActionButton(
              icon: Icons.mic_rounded,
              label: 'Voice',
              color: const Color(0xFF0A84FF),
              isHero: true,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onVoicePrompt?.call();
              },
            ),
            _buildDivider(),
          ],

          // Git Actions
          if (widget.onGitActions != null) ...[
            _buildActionButton(
              icon: Icons.difference_rounded,
              label: 'Git',
              color: const Color(0xFF30D158),
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onGitActions?.call();
              },
            ),
            _buildDivider(),
          ],

          // Floating Bubble
          if (widget.onBubble != null) ...[
            _buildActionButton(
              icon: widget.bubbleActive
                  ? Icons.bubble_chart_rounded
                  : Icons.bubble_chart_outlined,
              label: 'Bubble',
              color: widget.bubbleActive
                  ? const Color(0xFFFF9F0A)
                  : Colors.white70,
              isActive: widget.bubbleActive,
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onBubble?.call();
              },
            ),
            _buildDivider(),
          ],

          // Xoay màn hình
          if (widget.onToggleOrientation != null) ...[
            _buildActionButton(
              icon: widget.isLandscape
                  ? Icons.stay_current_portrait_rounded
                  : Icons.stay_current_landscape_rounded,
              label: widget.isLandscape ? 'Dọc' : 'Ngang',
              color: widget.isLandscape
                  ? const Color(0xFF38BDF8)
                  : Colors.white70,
              isActive: widget.isLandscape,
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onToggleOrientation?.call();
              },
            ),
            _buildDivider(),
          ],

          // Keep Awake (Sáng)
          _buildActionButton(
            icon: widget.isWakelockEnabled
                ? Icons.lightbulb_rounded
                : Icons.lightbulb_outline_rounded,
            label: 'Sáng',
            color: widget.isWakelockEnabled
                ? const Color(0xFFFFD60A)
                : Colors.white70,
            isActive: widget.isWakelockEnabled,
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onToggleWakelock();
            },
          ),
          _buildDivider(),

          // Tải lại
          _buildActionButton(
            icon: Icons.refresh_rounded,
            label: 'Tải lại',
            color: Colors.white70,
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onReload();
            },
          ),
          _buildDivider(),

          // Thêm (Overflow)
          _buildActionButton(
            icon: _showMore
                ? Icons.keyboard_arrow_up_rounded
                : Icons.more_horiz_rounded,
            label: 'Thêm',
            color: _showMore ? const Color(0xFF0A84FF) : Colors.white60,
            isActive: _showMore,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showMore = !_showMore);
            },
          ),

          // Thu gọn
          IconButton(
            tooltip: 'Thu gọn (hoặc chạm 2 lần)',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            icon: const Icon(
              Icons.close_fullscreen_rounded,
              size: 14,
              color: Colors.white38,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isMini = true;
                _showMore = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMoreMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A).withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.16),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Split Screen
          if (widget.onToggleSplit != null) ...[
            _buildSubMenuItem(
              icon: widget.isSplitActive
                  ? Icons.splitscreen_rounded
                  : Icons.splitscreen_outlined,
              label: widget.isSplitActive ? 'Bỏ chia đôi' : 'Chia đôi',
              color: widget.isSplitActive
                  ? const Color(0xFF38BDF8)
                  : Colors.white70,
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onToggleSplit?.call();
              },
            ),
            _buildDivider(),
          ],
          // Multi-Account
          _buildSubMenuItem(
            icon: Icons.manage_accounts_rounded,
            label: 'Tài khoản',
            color: const Color(0xFF0A84FF),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showMore = false);
              widget.onAccount();
            },
          ),
          _buildDivider(),
          // Copy URL
          _buildSubMenuItem(
            icon: Icons.link_rounded,
            label: 'Copy link',
            color: Colors.white70,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showMore = false);
              widget.onCopyUrl();
            },
          ),
          _buildDivider(),
          // Về Hub
          _buildSubMenuItem(
            icon: Icons.power_settings_new_rounded,
            label: 'Về Hub',
            color: const Color(0xFFFF453A),
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onExit();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
    bool isHero = false,
    bool isActive = false,
  }) {
    final effectiveColor = color ?? Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: effectiveColor.withOpacity(0.2),
        highlightColor: effectiveColor.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
          decoration: isHero
              ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0A84FF).withOpacity(0.28),
                      const Color(0xFF5E5CE6).withOpacity(0.18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF0A84FF).withOpacity(0.5),
                    width: 0.8,
                  ),
                )
              : (isActive
                  ? BoxDecoration(
                      color: effectiveColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: effectiveColor.withOpacity(0.38),
                        width: 0.8,
                      ),
                    )
                  : null),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 17, color: effectiveColor),
                  if (isActive && !isHero)
                    Positioned(
                      top: -1,
                      right: -3,
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: effectiveColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: effectiveColor.withOpacity(0.8),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isActive || isHero ? FontWeight.w600 : FontWeight.w500,
                  color: effectiveColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? Colors.white70;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: effectiveColor.withOpacity(0.2),
        highlightColor: effectiveColor.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: effectiveColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 16,
      width: 0.8,
      color: Colors.white.withOpacity(0.12),
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}
