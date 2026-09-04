import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/url_parser.dart';
import '../../../core/widgets/status_dot.dart';
import '../../../core/widgets/vht_card.dart';
import '../../../models/remote_session.dart';

class SessionCard extends StatelessWidget {
  final RemoteSession session;
  final VoidCallback onConnect;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;

  const SessionCard({
    super.key,
    required this.session,
    required this.onConnect,
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
    final shortId = UrlParser.getShortSessionId(session.id);
    final isRecent = DateTime.now().difference(session.lastAccessedAt).inHours < 2;

    return VhtCard(
      padding: const EdgeInsets.all(12),
      onTap: onConnect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(isOnline: isRecent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  session.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (session.isPinned)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.push_pin, size: 14, color: AppColors.brandPrimary),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                color: AppColors.surfaceDarkElevated,
                onSelected: (val) {
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
                    value: 'rename',
                    child: Text('Đổi tên gợi nhớ'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Xóa phiên này', style: TextStyle(color: AppColors.stateWarning)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID: $shortId • ${_formatTime(session.lastAccessedAt)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandPrimary,
                  side: const BorderSide(color: AppColors.brandPrimary, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: const Size(60, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: onConnect,
                child: const Text('Vào lại', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
