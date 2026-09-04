import 'package:flutter/material.dart';
import '../../../core/services/heartbeat_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/apple_card.dart';
import '../../../core/widgets/status_dot.dart';
import '../../../models/remote_session.dart';

class SessionCard extends StatelessWidget {
  final RemoteSession session;
  final DeviceStatus status;
  final VoidCallback onConnect;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const SessionCard({
    super.key,
    required this.session,
    this.status = DeviceStatus.checking,
    required this.onConnect,
    required this.onOpenInBrowser,
    required this.onRename,
    required this.onDelete,
    required this.onTogglePin,
  });

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa kết nối';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final badgeBg = isDark ? AppColors.darkPrimaryLight : AppColors.lightPrimaryLight;

    // Status styling
    Color statusColor;
    String statusLabel;
    String statusSubtitle;
    if (status == DeviceStatus.online) {
      statusColor = isDark ? AppColors.statusSuccessDark : AppColors.statusSuccess;
      statusLabel = 'Active';
      statusSubtitle = 'Sẵn sàng kết nối';
    } else if (status == DeviceStatus.offline) {
      statusColor = textSecondary;
      statusLabel = 'Offline';
      statusSubtitle = 'Chưa mở Antigravity 2.0';
    } else {
      statusColor = primaryColor;
      statusLabel = 'Kiểm tra';
      statusSubtitle = 'Đang kiểm tra kết nối...';
    }

    return AppleCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onConnect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(
                isOnline: status == DeviceStatus.online,
                size: 8,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        session.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (session.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin, size: 14, color: primaryColor),
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, size: 20, color: textSecondary),
                color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'browser') onOpenInBrowser();
                  if (val == 'rename') onRename();
                  if (val == 'delete') onDelete();
                  if (val == 'pin') onTogglePin();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'pin',
                    child: Text(session.isPinned ? 'Bỏ ghim' : 'Ghim lên đầu'),
                  ),
                  const PopupMenuItem(
                    value: 'browser',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_browser, size: 16),
                        SizedBox(width: 8),
                        Text('Mở trình duyệt ngoài'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Text('Đổi tên thiết bị'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa phiên này', style: TextStyle(color: AppColors.statusWarning)),
                  ),
                ],
              ),
            ],
          ),

          if (session.email != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alternate_email, size: 11, color: primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    session.email!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$statusSubtitle • ${_formatTime(session.lastAccessedAt)}',
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
              InkWell(
                onTap: onConnect,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        'Vào lại',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios, size: 10, color: primaryColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
