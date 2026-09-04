import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/theme/app_colors.dart';

class VoicePromptModal extends StatefulWidget {
  final SpeechService speechService;
  final Function(String text, bool autoSubmit) onSendPrompt;

  const VoicePromptModal({
    super.key,
    required this.speechService,
    required this.onSendPrompt,
  });

  @override
  State<VoicePromptModal> createState() => _VoicePromptModalState();
}

class _VoicePromptModalState extends State<VoicePromptModal>
    with SingleTickerProviderStateMixin {
  String _recognizedText = '';
  bool _isListening = false;
  String _selectedLocale = 'vi_VN';
  double _soundLevel = 0.0;
  String? _errorMessage;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _startListening();
  }

  @override
  void dispose() {
    _waveController.dispose();
    widget.speechService.stopListening();
    super.dispose();
  }

  Future<void> _startListening() async {
    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _isListening = true;
    });

    final isAvailable = await widget.speechService.initialize(
      onError: (err) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _errorMessage = 'Lỗi nhận diện: ${err.errorMsg}';
          });
        }
      },
      onStatus: (status) {
        if (mounted && (status == 'done' || status == 'notListening')) {
          setState(() {
            _isListening = false;
          });
        }
      },
    );

    if (!isAvailable) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _errorMessage =
              'Không thể truy cập Microphone hoặc dịch vụ nhận diện giọng nói.';
        });
      }
      return;
    }

    await widget.speechService.startListening(
      localeId: _selectedLocale,
      onResult: (text, isFinal) {
        if (mounted) {
          setState(() {
            _recognizedText = text;
            if (isFinal) _isListening = false;
          });
        }
      },
      onSoundLevel: (level) {
        if (mounted) {
          setState(() {
            _soundLevel = level.clamp(0.0, 10.0);
          });
        }
      },
    );
  }

  void _stopListening() async {
    HapticFeedback.selectionClick();
    await widget.speechService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _handleInsert(bool autoSubmit) {
    if (_recognizedText.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    widget.onSendPrompt(_recognizedText.trim(), autoSubmit);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final secondarySurface = isDark
        ? AppColors.darkSurfaceSecondary
        : AppColors.lightSurfaceSecondary;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final badgeBg =
        isDark ? AppColors.darkPrimaryLight : AppColors.lightPrimaryLight;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Indicator
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

              // Header with Language selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.mic_rounded,
                            color: primaryColor, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ra lệnh bằng Giọng nói',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            _isListening
                                ? 'Đang lắng nghe bạn nói...'
                                : 'Đã dừng thu âm',
                            style:
                                TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Dropdown chọn ngôn ngữ
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: secondarySurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLocale,
                        isDense: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            size: 18, color: textSecondary),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textPrimary),
                        dropdownColor: surfaceColor,
                        items: const [
                          DropdownMenuItem(
                              value: 'vi_VN', child: Text('🇻🇳 Tiếng Việt')),
                          DropdownMenuItem(
                              value: 'en_US', child: Text('🇺🇸 English')),
                        ],
                        onChanged: (val) {
                          if (val != null && val != _selectedLocale) {
                            setState(() {
                              _selectedLocale = val;
                            });
                            widget.speechService.stopListening();
                            _startListening();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Khung hiển thị văn bản nhận diện (Transcription Box)
              Container(
                constraints:
                    const BoxConstraints(minHeight: 110, maxHeight: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: secondarySurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isListening
                        ? primaryColor.withOpacity(0.5)
                        : borderColor,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_recognizedText.isEmpty && _errorMessage == null)
                        Text(
                          _isListening
                              ? 'Hãy nói yêu cầu (ví dụ: "Kiểm tra lỗi build và sửa giúp tôi")...'
                              : 'Chưa nhận diện được âm thanh. Hãy bấm thu âm lại.',
                          style: TextStyle(
                            fontSize: 14,
                            color: textSecondary.withOpacity(0.8),
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.statusWarning),
                        )
                      else
                        SelectableText(
                          _recognizedText,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Animated Sound Waves & Mic Controller
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Sóng âm trái
                  _buildSoundWave(isLeft: true, primaryColor: primaryColor),
                  const SizedBox(width: 16),

                  // Mic Button (Tap to toggle)
                  GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening
                            ? AppColors.statusWarning
                            : primaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: (_isListening
                                    ? AppColors.statusWarning
                                    : primaryColor)
                                .withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening
                            ? Icons.stop_rounded
                            : Icons.mic_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),
                  // Sóng âm phải
                  _buildSoundWave(isLeft: false, primaryColor: primaryColor),
                ],
              ),
              const SizedBox(height: 18),

              // Các nút hành động: "Chèn vào ô chat" & "Gửi ngay"
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _recognizedText.trim().isEmpty
                          ? null
                          : () => _handleInsert(false),
                      icon: Icon(Icons.edit_note_rounded,
                          size: 18,
                          color: _recognizedText.trim().isEmpty
                              ? textSecondary
                              : textPrimary),
                      label: Text(
                        'Chèn vào ô chat',
                        style: TextStyle(
                          color: _recognizedText.trim().isEmpty
                              ? textSecondary
                              : textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: primaryColor.withOpacity(0.35),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _recognizedText.trim().isEmpty
                          ? null
                          : () => _handleInsert(true),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text(
                        'Gửi ngay',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoundWave({required bool isLeft, required Color primaryColor}) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final double base = _isListening ? (0.3 + (_soundLevel / 15.0).clamp(0.0, 0.7)) : 0.15;
        final double wave1 = (base * (0.8 + 0.4 * _waveController.value)).clamp(0.1, 1.0);
        final double wave2 = (base * (1.2 - 0.4 * _waveController.value)).clamp(0.1, 1.0);
        final double wave3 = (base * (0.6 + 0.6 * _waveController.value)).clamp(0.1, 1.0);

        final heights = isLeft ? [wave3, wave2, wave1] : [wave1, wave2, wave3];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: heights.map((h) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3.5,
              height: 24 * h,
              decoration: BoxDecoration(
                color: _isListening
                    ? primaryColor.withOpacity(0.85)
                    : AppColors.statusNeutral.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
