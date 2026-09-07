import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GitPreset {
  final String title;
  final String command;
  final String prompt;
  final IconData icon;
  final Color accentColor;

  const GitPreset({
    required this.title,
    required this.command,
    required this.prompt,
    required this.icon,
    required this.accentColor,
  });
}

class GitActionsModal extends StatefulWidget {
  final void Function(String prompt, bool autoSubmit) onSendPrompt;

  const GitActionsModal({
    super.key,
    required this.onSendPrompt,
  });

  @override
  State<GitActionsModal> createState() => _GitActionsModalState();
}

class _GitActionsModalState extends State<GitActionsModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _customCommandController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const List<GitPreset> _diffPresets = [
    GitPreset(
      title: 'Kiểm tra file thay đổi',
      command: 'git status',
      prompt: 'Chạy git status để kiểm tra danh sách file đã thay đổi',
      icon: Icons.checklist_rounded,
      accentColor: Color(0xFF0A84FF),
    ),
    GitPreset(
      title: 'Xem chi tiết code diff',
      command: 'git diff',
      prompt: 'Chạy git diff để in ra chi tiết các thay đổi code vừa sửa',
      icon: Icons.difference_rounded,
      accentColor: Color(0xFF30D158),
    ),
    GitPreset(
      title: 'Tóm tắt dòng thêm / bớt',
      command: 'git diff --stat',
      prompt: 'Chạy git diff --stat tóm tắt số lượng dòng code thêm/bớt theo từng file',
      icon: Icons.insert_chart_outlined_rounded,
      accentColor: Color(0xFF5E5CE6),
    ),
    GitPreset(
      title: 'So sánh với commit trước',
      command: 'git diff HEAD~1',
      prompt: 'Chạy git diff HEAD~1 để so sánh với commit trước',
      icon: Icons.history_toggle_off_rounded,
      accentColor: Color(0xFFFF9F0A),
    ),
  ];

  static const List<GitPreset> _historyPresets = [
    GitPreset(
      title: 'Lịch sử 5 commit gần nhất',
      command: 'git log -n 5 --oneline',
      prompt: 'Chạy git log -n 5 --oneline để xem các commit gần nhất',
      icon: Icons.format_list_bulleted_rounded,
      accentColor: Color(0xFF0A84FF),
    ),
    GitPreset(
      title: 'Chi tiết commit vừa tạo',
      command: 'git show HEAD',
      prompt: 'Chạy git show HEAD để xem chi tiết commit vừa tạo gần nhất',
      icon: Icons.search_rounded,
      accentColor: Color(0xFF30D158),
    ),
    GitPreset(
      title: 'Danh sách các branch',
      command: 'git branch -a',
      prompt: 'Chạy git branch -a để xem danh sách tất cả các nhánh',
      icon: Icons.fork_right_rounded,
      accentColor: Color(0xFFBF5AF2),
    ),
  ];

  static const List<GitPreset> _actionPresets = [
    GitPreset(
      title: 'Smart Commit',
      command: 'Tự động commit',
      prompt: 'Tạo git commit với message ngắn gọn mô tả chính xác các thay đổi vừa làm',
      icon: Icons.add_task_rounded,
      accentColor: Color(0xFF30D158),
    ),
    GitPreset(
      title: 'Hoàn tác tất cả thay đổi',
      command: 'git restore .',
      prompt: 'Chạy git restore . để hoàn tác tất cả các thay đổi chưa commit',
      icon: Icons.undo_rounded,
      accentColor: Color(0xFFFF453A),
    ),
    GitPreset(
      title: 'Tạm cất thay đổi (Stash)',
      command: 'git stash',
      prompt: 'Chạy git stash để tạm cất các thay đổi hiện tại',
      icon: Icons.inventory_2_outlined,
      accentColor: Color(0xFFFF9F0A),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customCommandController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSelectPreset(GitPreset preset, {required bool autoSubmit}) {
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    widget.onSendPrompt(preset.prompt, autoSubmit);
  }

  void _handleSendCustomCommand({required bool autoSubmit}) {
    final text = _customCommandController.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    widget.onSendPrompt(text, autoSubmit);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black;
    const textSecondary = Color(0xFF8E8E93);
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.72,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: borderColor.withOpacity(0.6),
            width: 0.8,
          ),
        ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Pull Indicator
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30D158).withOpacity(0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.difference_rounded,
                        size: 20,
                        color: Color(0xFF30D158),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Git & Code Diff Lệnh Nhanh',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const Text(
                            '1-chạm gửi lệnh cho AI Agent trong chat',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Segmented Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    labelColor: isDark ? Colors.white : Colors.black,
                    unselectedLabelColor: textSecondary,
                    labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    tabs: const [
                      Tab(text: 'Diff & Status'),
                      Tab(text: 'Lịch sử'),
                      Tab(text: 'Tác vụ'),
                    ],
                  ),
                ),
              ),

              // Tab View Contents
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPresetList(_diffPresets, isDark),
                    _buildPresetList(_historyPresets, isDark),
                    _buildPresetList(_actionPresets, isDark),
                  ],
                ),
              ),

              // Custom Command Bar at bottom
              _buildCustomCommandBar(isDark),
            ],
          ),
        ),
      );
    }

  Widget _buildPresetList(List<GitPreset> presets, bool isDark) {
    final textPrimary = isDark ? Colors.white : Colors.black;
    const textSecondary = Color(0xFF8E8E93);
    final cardBg = isDark ? const Color(0xFF242426) : const Color(0xFFF2F2F7);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: presets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = presets[index];
        return InkWell(
          onTap: () => _handleSelectPreset(item, autoSubmit: true),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: item.accentColor.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Preset Icon Badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.accentColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: item.accentColor,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Command Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          item.command,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: item.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Insert without submit button
                IconButton(
                  tooltip: 'Chèn vào ô chat để sửa thêm',
                  icon: const Icon(Icons.edit_note_rounded, size: 22, color: textSecondary),
                  onPressed: () => _handleSelectPreset(item, autoSubmit: false),
                ),

                // Send icon indicator
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: item.accentColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 16,
                    color: item.accentColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomCommandBar(bool isDark) {
    final textPrimary = isDark ? Colors.white : Colors.black;
    const textSecondary = Color(0xFF8E8E93);
    final barBg = isDark ? const Color(0xFF141415) : const Color(0xFFF2F2F7);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: barBg,
        border: Border(
          top: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF242426) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '\$ ',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF30D158),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _customCommandController,
                        focusNode: _focusNode,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Nhập lệnh git tùy ý...',
                          hintStyle: TextStyle(
                            fontFamily: 'sans-serif',
                            fontSize: 13,
                            color: textSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _handleSendCustomCommand(autoSubmit: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send Button
            InkWell(
              onTap: () => _handleSendCustomCommand(autoSubmit: true),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF30D158),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
