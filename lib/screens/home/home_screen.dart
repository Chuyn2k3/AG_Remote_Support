import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_parser.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/apple_card.dart';
import '../../models/remote_session.dart';
import '../scanner/scanner_screen.dart';
import '../remote/remote_screen.dart';
import 'widgets/qr_hero_card.dart';
import 'widgets/session_card.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final ValueNotifier<ThemeMode>? themeNotifier;

  const HomeScreen({
    super.key,
    required this.storageService,
    this.themeNotifier,
  });

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

    final email = UrlParser.extractEmail(url);
    final existingIndex = _sessions.indexWhere((s) => s.id == sessionId);
    RemoteSession session;

    if (existingIndex >= 0) {
      session = _sessions[existingIndex];
      session.lastAccessedAt = DateTime.now();
      if (email != null) {
        session.email = email;
      }
    } else {
      session = RemoteSession(
        id: sessionId,
        rawUrl: url,
        email: email,
        title: email != null
            ? '$email • ${UrlParser.getShortSessionId(sessionId)}'
            : 'Desktop • ${UrlParser.getShortSessionId(sessionId)}',
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            content: Text(
              'Clipboard không chứa link Antigravity hợp lệ',
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showRenameDialog(RemoteSession session) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final controller = TextEditingController(text: session.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Đổi tên thiết bị',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: textPrimary),
          decoration: InputDecoration(
            hintText: 'Ví dụ: MacBook Công Ty',
            hintStyle: TextStyle(color: textSecondary),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: textSecondary)),
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

  Future<void> _setThemeMode(ThemeMode mode) async {
    if (widget.themeNotifier != null) {
      widget.themeNotifier!.value = mode;
    }
    await widget.storageService.saveThemeMode(mode);
    setState(() {});
  }

  Widget _buildThemeMenu(BuildContext context) {
    final currentMode = widget.themeNotifier?.value ?? widget.storageService.getThemeMode();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    IconData themeIcon;
    if (currentMode == ThemeMode.light) {
      themeIcon = Icons.light_mode;
    } else if (currentMode == ThemeMode.dark) {
      themeIcon = Icons.dark_mode;
    } else {
      themeIcon = isDark ? Icons.brightness_auto : Icons.brightness_auto_outlined;
    }

    return PopupMenuButton<ThemeMode>(
      tooltip: 'Chế độ giao diện',
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
          shape: BoxShape.circle,
        ),
        child: Icon(themeIcon, size: 18, color: textSecondary),
      ),
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: _setThemeMode,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ThemeMode.system,
          child: Row(
            children: [
              const Icon(Icons.brightness_auto, size: 18),
              const SizedBox(width: 10),
              const Text('Hệ thống (Tự động)'),
              if (currentMode == ThemeMode.system) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.light,
          child: Row(
            children: [
              const Icon(Icons.light_mode, size: 18),
              const SizedBox(width: 10),
              const Text('Giao diện Sáng'),
              if (currentMode == ThemeMode.light) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              ],
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child: Row(
            children: [
              const Icon(Icons.dark_mode, size: 18),
              const SizedBox(width: 10),
              const Text('Giao diện Tối'),
              if (currentMode == ThemeMode.dark) ...[
                const Spacer(),
                Icon(Icons.check, size: 16, color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Antigravity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Remote Manager',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          _buildThemeMenu(context),
          const SizedBox(width: 12),
        ],
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'THIẾT BỊ GẦN ĐÂY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (_sessions.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await widget.storageService.clearAll();
                        _loadSessions();
                      },
                      child: Text(
                        'Xóa tất cả',
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Sessions List or Empty State
            if (_sessions.isEmpty)
              AppleCard(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.devices_rounded,
                      size: 40,
                      color: textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Chưa có thiết bị nào',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mở Antigravity 2.0 trên máy tính và bấm "Mở Camera" để kết nối.',
                      style: TextStyle(fontSize: 12, color: textSecondary),
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
                      onOpenInBrowser: () async {
                        await InAppBrowser.openWithSystemBrowser(url: WebUri(s.rawUrl));
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
