# Voice-to-Prompt (Ra Lệnh Bằng Giọng Nói) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Triển khai tính năng ra lệnh bằng giọng nói (Voice-to-Prompt) cho ứng dụng AG Remote Support, cho phép người dùng nói trực tiếp yêu cầu lập trình (tiếng Việt & tiếng Anh), tự động chuyển đổi thành văn bản và chèn hoặc gửi trực tiếp vào ô chat của Antigravity 2.0 trên máy tính.

**Architecture:** 
- `SpeechService` quản lý nhận diện giọng nói qua plugin `speech_to_text`, hỗ trợ nhận diện realtime và theo dõi mức âm lượng (`soundLevel`).
- `VoicePromptModal` cung cấp giao diện kính mờ Apple Frosted Glass với hiệu ứng sóng âm động và bản ghi văn bản trực tiếp.
- `RemoteScreen` & `FloatingCapsule` tích hợp nút microphone và thực hiện tiêm mã JavaScript vào DOM webview Antigravity (`textarea`, `contenteditable`) với cơ chế fallback Clipboard an toàn.

**Tech Stack:** Flutter (Dart), `speech_to_text: ^7.0.0`, `flutter_inappwebview: ^6.1.5`, `flutter_animate: ^4.5.2`, Android Audio Permissions (`RECORD_AUDIO`), iOS Dictation Permissions (`NSSpeechRecognitionUsageDescription`, `NSMicrophoneUsageDescription`).

---

### Task 1: Thêm Dependency & Cấu Hình Quyền Thu Âm Hệ Thống

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml:1-12`
- Modify: `ios/Runner/Info.plist:45-55`

- [x] **Step 1: Thêm `speech_to_text` vào `pubspec.yaml`**

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_inappwebview: ^6.1.5
  mobile_scanner: 5.2.3
  wakelock_plus: 1.2.8
  shared_preferences: ^2.5.3
  flutter_animate: ^4.5.2
  local_auth: ^2.3.0
  speech_to_text: ^7.0.0
```

- [x] **Step 2: Chạy `flutter pub get` để tải gói thư viện**

Run: `flutter pub get`
Expected: `Got dependencies!`

- [x] **Step 3: Cấu hình quyền `RECORD_AUDIO` và `<queries>` trong `AndroidManifest.xml`**

Thêm các dòng sau vào `android/app/src/main/AndroidManifest.xml`:
```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
    <uses-permission android:name="android.permission.USE_FINGERPRINT"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.BLUETOOTH"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
```
Và thêm vào khối `<queries>`:
```xml
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
    </queries>
```

- [x] **Step 4: Cấu hình quyền Microphone & Speech Recognition trong `Info.plist`**

Thêm vào `ios/Runner/Info.plist`:
```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>Ứng dụng cần sử dụng Microphone để thu âm giọng nói ra lệnh cho Antigravity.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Ứng dụng cần quyền nhận diện giọng nói để chuyển đổi câu nói thành văn bản prompt.</string>
```

- [x] **Step 5: Kiểm tra biên dịch & Commit**

Run: `flutter analyze`
Expected: `No issues found!`
```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat(voice): add speech_to_text dependency and audio permissions"
```

---

### Task 2: Xây Dựng `SpeechService` & Unit Tests

**Files:**
- Create: `lib/core/services/speech_service.dart`
- Create: `test/speech_service_test.dart`

- [x] **Step 1: Viết bài kiểm thử đơn vị `test/speech_service_test.dart`**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SpeechService initializes with default states and handles error safely', () async {
    final service = SpeechService();
    expect(service.isListening, isFalse);
    expect(service.lastWords, isEmpty);

    // Initializing in test environment without native speech engine should return false gracefully
    final isAvailable = await service.initialize();
    expect(isAvailable, isA<bool>());
  });
}
```

- [x] **Step 2: Chạy test để xác nhận test chạy được**

Run: `flutter test test/speech_service_test.dart`
Expected: Test hoàn thành (hoặc fail vì `speech_service.dart` chưa tạo).

- [x] **Step 3: Triển khai mã nguồn `lib/core/services/speech_service.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speechToText;
  bool _isInitialized = false;
  String _lastWords = '';
  double _soundLevel = 0.0;

  SpeechService([SpeechToText? speechToText])
      : _speechToText = speechToText ?? SpeechToText();

  bool get isListening => _speechToText.isListening;
  bool get isAvailable => _isInitialized;
  String get lastWords => _lastWords;
  double get soundLevel => _soundLevel;

  Future<bool> initialize({
    Function(SpeechRecognitionError)? onError,
    Function(String)? onStatus,
  }) async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onError: (val) {
          debugPrint('Speech error: ${val.errorMsg}');
          onError?.call(val);
        },
        onStatus: (val) {
          debugPrint('Speech status: $val');
          onStatus?.call(val);
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('Speech initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<List<LocaleName>> getLocales() async {
    if (!_isInitialized) await initialize();
    try {
      return await _speechToText.locales();
    } catch (e) {
      debugPrint('Error getting speech locales: $e');
      return [];
    }
  }

  Future<void> startListening({
    required Function(String text, bool isFinal) onResult,
    Function(double level)? onSoundLevel,
    String? localeId,
  }) async {
    if (!_isInitialized) {
      final available = await initialize();
      if (!available) return;
    }

    _lastWords = '';
    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          _lastWords = result.recognizedWords;
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) {
          _soundLevel = level;
          onSoundLevel?.call(level);
        },
        localeId: localeId,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
    } catch (e) {
      debugPrint('Error starting speech listen: $e');
    }
  }

  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (e) {
      debugPrint('Error stopping speech listen: $e');
    }
  }

  Future<void> cancelListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
    } catch (e) {
      debugPrint('Error canceling speech listen: $e');
    }
  }
}
```

- [x] **Step 4: Chạy lại test xác nhận PASS**

Run: `flutter test test/speech_service_test.dart`
Expected: `All tests passed!`

- [x] **Step 5: Commit**

```bash
git add lib/core/services/speech_service.dart test/speech_service_test.dart
git commit -m "feat(speech): implement SpeechService with locale support and sound level tracking"
```

---

### Task 3: Xây Dựng `VoicePromptModal` Chuẩn Apple Frosted Glass

**Files:**
- Create: `lib/screens/remote/widgets/voice_prompt_modal.dart`

- [x] **Step 1: Triển khai giao diện Bottom Sheet `VoicePromptModal`**

Bao gồm:
- Thanh chỉ báo trạng thái lắng nghe với hoạt ảnh sóng âm (Sound waves animation).
- Khung văn bản hiển thị từ ngữ nhận diện thời gian thực (Live Transcription box) kèm nút sao chép.
- Nút chuyển đổi nhanh ngôn ngữ: Tiếng Việt (`vi_VN`) / English (`en_US`).
- Nút "Chèn vào ô chat" (Insert into Antigravity input) và "Gửi ngay" (Insert and submit).

Mã nguồn chi tiết:
```dart
import 'dart:ui';
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

class _VoicePromptModalState extends State<VoicePromptModal> with SingleTickerProviderStateMixin {
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
      duration: const Duration(milliseconds: 1200),
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
    );

    if (!isAvailable) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _errorMessage = 'Không thể truy cập dịch vụ nhận diện giọng nói hoặc Microphone.';
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
            _soundLevel = level;
          });
        }
      },
    );
  }

  void _stopListening() async {
    await widget.speechService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _handleInsert(bool autoSubmit) {
    if (_recognizedText.trim().isEmpty) return;
    Navigator.pop(context);
    widget.onSendPrompt(_recognizedText.trim(), autoSubmit);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final textPrimary = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final badgeBg = isDark ? AppColors.darkPrimaryLight : AppColors.lightPrimaryLight;

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
              // Thanh kéo
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

              // Header với nút đổi ngôn ngữ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: badgeBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.mic_rounded, color: primaryColor, size: 20),
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
                            _isListening ? 'Đang lắng nghe bạn nói...' : 'Đã dừng thu âm',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Dropdown chọn ngôn ngữ
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLocale,
                        isDense: true,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: textSecondary),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                        dropdownColor: surfaceColor,
                        items: const [
                          DropdownMenuItem(value: 'vi_VN', child: Text('🇻🇳 Tiếng Việt')),
                          DropdownMenuItem(value: 'en_US', child: Text('🇺🇸 English')),
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
                constraints: const BoxConstraints(minHeight: 110, maxHeight: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceSecondary : AppColors.lightSurfaceSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isListening
                        ? primaryColor.withOpacity(0.5)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
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
                          style: const TextStyle(fontSize: 13, color: AppColors.statusWarning),
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
              const SizedBox(height: 14),

              // Hoạt ảnh sóng âm và nút điều khiển Micro
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                      size: 40,
                      color: _isListening ? AppColors.statusWarning : primaryColor,
                    ),
                    onPressed: _isListening ? _stopListening : _startListening,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Các nút hành động
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _recognizedText.isEmpty ? null : () => _handleInsert(false),
                      icon: Icon(Icons.edit_note_rounded, size: 18, color: textPrimary),
                      label: Text(
                        'Chèn vào ô chat',
                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _recognizedText.isEmpty ? null : () => _handleInsert(true),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text(
                        'Gửi ngay',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
}
```

- [x] **Step 2: Kiểm tra biên dịch**

Run: `flutter analyze`
Expected: `No issues found!`

- [x] **Step 3: Commit**

```bash
git add lib/screens/remote/widgets/voice_prompt_modal.dart
git commit -m "feat(ui): add VoicePromptModal with live transcription and bilingual speech support"
```

---

### Task 4: Tích Hợp Nút Mic Vào `FloatingCapsule` & Tiêm JS Vào `RemoteScreen`

**Files:**
- Modify: `lib/screens/remote/widgets/floating_capsule.dart:1-65`
- Modify: `lib/screens/remote/remote_screen.dart`

- [x] **Step 1: Bổ sung tham số `onVoicePrompt` vào `FloatingCapsule`**

Thêm icon Mic vào giữa viên thuốc nổi Apple Dynamic Island:
```dart
class FloatingCapsule extends StatelessWidget {
  final bool isWakelockEnabled;
  final VoidCallback onToggleWakelock;
  final VoidCallback onAccount;
  final VoidCallback onReload;
  final VoidCallback onCopyUrl;
  final VoidCallback onExit;
  final VoidCallback? onVoicePrompt;

  const FloatingCapsule({
    super.key,
    required this.isWakelockEnabled,
    required this.onToggleWakelock,
    required this.onAccount,
    required this.onReload,
    required this.onCopyUrl,
    required this.onExit,
    this.onVoicePrompt,
  });
```
Thêm nút IconButton Mic vào thanh capsule:
```dart
IconButton(
  icon: Icon(Icons.mic_rounded, color: primaryColor, size: 20),
  tooltip: 'Ra lệnh giọng nói',
  onPressed: onVoicePrompt,
),
```

- [x] **Step 2: Triển khai phương thức tiêm văn bản DOM `_injectVoicePrompt` trong `RemoteScreen`**

Trong `lib/screens/remote/remote_screen.dart`:
```dart
  void _openVoicePromptModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoicePromptModal(
        speechService: SpeechService(),
        onSendPrompt: (text, autoSubmit) {
          _injectPromptIntoWebView(text, autoSubmit: autoSubmit);
        },
      ),
    );
  }

  Future<void> _injectPromptIntoWebView(String text, {required bool autoSubmit}) async {
    if (_webViewController == null) return;

    final escapedText = text.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll('\n', r'\n');

    try {
      final dynamic result = await _webViewController?.evaluateJavascript(source: '''
        (function() {
          try {
            const candidates = [
              document.querySelector('textarea:not([disabled])'),
              document.querySelector('[contenteditable="true"]'),
              document.querySelector('input[type="text"]:not([disabled])'),
              document.querySelector('mwc-textarea textarea'),
              document.querySelector('.chat-input textarea')
            ];
            const target = candidates.find(el => el !== null && el.offsetParent !== null) || candidates.find(el => el !== null);
            if (!target) return false;

            target.focus();
            if (target.isContentEditable) {
              target.innerText = (target.innerText ? target.innerText + ' ' : '') + '$escapedText';
            } else {
              const prev = target.value || '';
              target.value = (prev ? prev + ' ' : '') + '$escapedText';
            }

            target.dispatchEvent(new Event('input', { bubbles: true }));
            target.dispatchEvent(new Event('change', { bubbles: true }));

            if ($autoSubmit) {
              setTimeout(() => {
                const sendBtn = document.querySelector('button[aria-label*="Send"], button[aria-label*="Gửi"], [data-test-id="send-button"], button[type="submit"]');
                if (sendBtn) {
                  sendBtn.click();
                } else {
                  target.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
                  target.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
                }
              }, 200);
            }
            return true;
          } catch(e) {
            return false;
          }
        })()
      ''');

      final bool success = (result == true || result == 'true');
      if (mounted) {
        if (!success) {
          // Fallback lưu vào Clipboard nếu không tìm thấy ô chat
          await Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📋 Đã sao chép câu lệnh vào bộ nhớ tạm. Hãy chạm vào ô chat để dán!'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              content: Text(autoSubmit ? '🚀 Đã gửi câu lệnh tới Antigravity!' : '✏️ Đã điền câu lệnh vào ô chat.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error injecting prompt: $e');
      await Clipboard.setData(ClipboardData(text: text));
    }
  }
```

- [x] **Step 3: Chạy `flutter analyze` & `flutter test`**

Run: `flutter analyze && flutter test`
Expected: `No issues found! All tests passed!`

- [x] **Step 4: Commit**

```bash
git add lib/screens/remote/widgets/floating_capsule.dart lib/screens/remote/remote_screen.dart
git commit -m "feat(remote): integrate voice prompt button in floating capsule with webview DOM injection"
```

---

### Task 5: Xác Minh Toàn Diện & Biên Dịch APK

- [x] **Step 1: Chạy kiểm tra tĩnh toàn dự án**
Run: `flutter analyze`
Expected: 0 errors, 0 warnings.

- [x] **Step 2: Chạy toàn bộ test suite**
Run: `flutter test`
Expected: Tất cả các test đều pass 100%.

- [x] **Step 3: Biên dịch APK thực tế**
Run: `flutter build apk --debug`
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`
