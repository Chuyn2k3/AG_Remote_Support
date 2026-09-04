import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_parser.dart';
import '../../core/services/storage_service.dart';
import '../../models/remote_session.dart';
import '../scanner/scanner_screen.dart';
import '../remote/remote_screen.dart';
import 'widgets/qr_hero_card.dart';
import 'widgets/session_card.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;

  const HomeScreen({super.key, required this.storageService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late List<RemoteSession> _sessions;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    setState(() {
      _sessions = widget.storageService.getSessions();
    });
  }

  Future<void> _handleScannedUrl(String url) async {
    final sessionId = UrlParser.extractSessionId(url);
    if (sessionId == null) return;

    final existingIndex = _sessions.indexWhere((s) => s.id == sessionId);
    RemoteSession session;

    if (existingIndex >= 0) {
      session = _sessions[existingIndex];
      session.lastAccessedAt = DateTime.now();
    } else {
      session = RemoteSession(
        id: sessionId,
        rawUrl: url,
        title: 'Desktop • ${UrlParser.getShortSessionId(sessionId)}',
        createdAt: DateTime.now(),
        lastAccessedAt: DateTime.now(),
      );
    }

    await widget.storageService.upsertSession(session);
    _loadSessions();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RemoteScreen(session: session)),
      ).then((_) => _loadSessions());
    }
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result != null && mounted) {
      _handleScannedUrl(result);
    }
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (UrlParser.isAntigravityUrl(text)) {
      _handleScannedUrl(text);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.surfaceDark,
            content: Text(
              'Clipboard không chứa link Antigravity hợp lệ',
              style: TextStyle(color: AppColors.stateWarning),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showRenameDialog(RemoteSession session) async {
    final controller = TextEditingController(text: session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDarkElevated,
        title: const Text('Đổi tên phiên làm việc', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Ví dụ: MacBook Công Ty',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.brandPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      session.title = newTitle;
      await widget.storageService.upsertSession(session);
      _loadSessions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.brandPrimary.withOpacity(0.4)),
              ),
              child: const Text(
                'REMOTE 2.0',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimaryLight,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('Antigravity Hub'),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // QR Scan Card
            QrHeroCard(
              onOpenScanner: _openScanner,
              onPasteLink: _pasteLink,
            ),
            const SizedBox(height: 24),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PHIÊN GẦN ĐÂY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                if (_sessions.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await widget.storageService.clearAll();
                      _loadSessions();
                    },
                    child: const Text(
                      'Xóa tất cả',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Sessions List or Empty State
            if (_sessions.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.devices_other, size: 36, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'Chưa có phiên làm việc nào',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Quét mã QR trên Antigravity Desktop để bắt đầu điều khiển.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._sessions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SessionCard(
                      session: s,
                      onConnect: () {
                        s.lastAccessedAt = DateTime.now();
                        widget.storageService.upsertSession(s);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => RemoteScreen(session: s)),
                        ).then((_) => _loadSessions());
                      },
                      onRename: () => _showRenameDialog(s),
                      onDelete: () async {
                        await widget.storageService.deleteSession(s.id);
                        _loadSessions();
                      },
                      onTogglePin: () async {
                        s.isPinned = !s.isPinned;
                        await widget.storageService.upsertSession(s);
                        _loadSessions();
                      },
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
