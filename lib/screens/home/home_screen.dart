import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/services/heartbeat_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/url_parser.dart';
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
  Map<String, DeviceStatus> _deviceStatuses = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _refreshDeviceStatuses();
  }

  void _loadSessions() {
    setState(() {
      _sessions = widget.storageService.getSessions();
    });
  }

  Future<void> _refreshDeviceStatuses() async {
    if (_sessions.isEmpty) return;
    setState(() {
      for (final s in _sessions) {
        _deviceStatuses[s.id] = DeviceStatus.checking;
      }
    });

    final statuses = await HeartbeatService.pingAll(_sessions);
    if (mounted) {
      setState(() {
        _deviceStatuses = statuses;
      });
    }
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
    _refreshDeviceStatuses();

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RemoteScreen(
            session: session,
            storageService: widget.storageService,
          ),
        ),
      ).then((_) {
        _loadSessions();
        _refreshDeviceStatuses();
      });
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

  Future<void> _showConfirmClearAllDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xóa tất cả thiết bị?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
        ),
        content: Text(
          'Toàn bộ danh sách thiết bị và phiên làm việc đã lưu sẽ bị xóa khỏi điện thoại. Thao tác này không thể hoàn tác.',
          style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Hủy', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Xóa tất cả',
              style: TextStyle(color: AppColors.statusWarning, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (shouldClear == true) {
      await widget.storageService.clearAll();
      _loadSessions();
      setState(() {
        _deviceStatuses.clear();
      });
    }
  }

  void _showGuideBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final badgeBg = isDark ? AppColors.darkPrimaryLight : AppColors.lightPrimaryLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hướng Dẫn Sử Dụng AG Remote',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '4 bước đơn giản để kết nối và điều khiển máy tính từ xa',
                style: TextStyle(fontSize: 13, color: textSecondary),
              ),
              const SizedBox(height: 20),

              _buildGuideStep(
                step: '1',
                title: 'Mở Antigravity 2.0 trên máy tính',
                description: 'Khởi động phần mềm Antigravity 2.0 trên máy tính của bạn (macOS, Windows hoặc Linux).',
                primaryColor: primaryColor,
                badgeBg: badgeBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 14),

              _buildGuideStep(
                step: '2',
                title: 'Bật tính năng Remote Control',
                description: 'Trên Antigravity 2.0 máy tính, vào mục Application (hoặc thanh công cụ) và bật Remote Control.',
                primaryColor: primaryColor,
                badgeBg: badgeBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 14),

              _buildGuideStep(
                step: '3',
                title: 'Quét mã QR bằng Camera',
                description: 'Mã QR kết nối sẽ hiển thị trên màn hình Desktop. Bấm nút "Mở Camera" trên app này để quét mã.',
                primaryColor: primaryColor,
                badgeBg: badgeBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 14),

              _buildGuideStep(
                step: '4',
                title: 'Bắt đầu làm việc & Giữ kết nối',
                description: 'App sẽ tự động mở phiên remote. Hãy giữ Antigravity 2.0 luôn mở trên máy tính để duy trì kết nối.',
                primaryColor: primaryColor,
                badgeBg: badgeBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Đã hiểu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideStep({
    required String step,
    required String title,
    required String description,
    required Color primaryColor,
    required Color badgeBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeBg,
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
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
      themeIcon = Icons.light_mode_rounded;
    } else if (currentMode == ThemeMode.dark) {
      themeIcon = Icons.dark_mode_rounded;
    } else {
      themeIcon = isDark ? Icons.brightness_auto_rounded : Icons.brightness_auto_outlined;
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

  Widget _buildHelpButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: _showGuideBottomSheet,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.help_outline_rounded, size: 18, color: textSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AG Remote Support',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            Text(
              'Desktop Companion',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          _buildHelpButton(context),
          const SizedBox(width: 8),
          _buildThemeMenu(context),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          onRefresh: _refreshDeviceStatuses,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            physics: const AlwaysScrollableScrollPhysics(),
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
                        onPressed: _showConfirmClearAllDialog,
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
                        status: _deviceStatuses[s.id] ?? DeviceStatus.checking,
                        onConnect: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RemoteScreen(
                                session: s,
                                storageService: widget.storageService,
                              ),
                            ),
                          ).then((_) {
                            _loadSessions();
                            _refreshDeviceStatuses();
                          });
                        },
                        onOpenInBrowser: () async {
                          await InAppBrowser.openWithSystemBrowser(url: WebUri(s.rawUrl));
                        },
                        onRename: () => _showRenameDialog(s),
                        onDelete: () async {
                          await widget.storageService.deleteSession(s.id);
                          _loadSessions();
                          setState(() {
                            _deviceStatuses.remove(s.id);
                          });
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
      ),
    );
  }
}
