# Design Spec: Mobile Git Quick Actions & Diff Toolbar for CLI Agent

- **Date:** 2026-09-04
- **Topic:** Quick Git commands and Diff review shortcuts for Antigravity Remote CLI chat interface.
- **Status:** Approved by User

---

## 1. Overview & Context
The Antigravity 2.0 remote web interface on mobile is a CLI-based agent chat stream rather than a traditional multi-window IDE. Users interact by typing prompts and reading terminal/agent outputs.

Typing verbose Git commands (e.g. `git status`, `git diff --stat`, `git log -n 5`) on mobile virtual keyboards is slow and cumbersome. This feature provides a 1-tap Git control panel accessible directly from the floating overlay capsule.

---

## 2. Architecture & UX Design

### 2.1 Trigger Button on `FloatingCapsule`
- Add a new **Git Action** button on `FloatingCapsule` (`lib/screens/remote/widgets/floating_capsule.dart`).
- Icon: `Icons.commit_rounded` or `Icons.difference_rounded`.
- Color: Apple Green (`AppColors.statusSuccess`) or Apple System Blue (`AppColors.darkPrimary`).
- Positioned alongside Voice Prompt and screen brightness toggles.

### 2.2 Git Quick Actions Bottom Sheet (`GitActionsModal`)
A modal bottom sheet styled in Apple Cupertino Clean HIG (Glassmorphic dark background `0xFF1C1C1E`, blur filter, rounded top corners):
1. **Header:** Title "Git & Diff Lệnh Nhanh" with a dismiss button.
2. **Preset Categories:**
   - **🔍 Trạng thái & So sánh (Diff & Status):**
     - 📊 `git status` — *"Chạy git status để kiểm tra danh sách file đã thay đổi"*
     - 📝 `git diff` — *"Chạy git diff để in ra chi tiết các thay đổi"*
     - 📉 `git diff --stat` — *"Chạy git diff --stat tóm tắt số dòng code thêm/bớt"*
     - 🔍 `git diff HEAD~1` — *"Xem chi tiết thay đổi so với commit trước"*
   - **📜 Lịch sử & Kiểm tra (History):**
     - 📜 `git log` — *"Chạy git log -n 5 --oneline"*
     - 🔎 `git show HEAD` — *"Chạy git show HEAD để xem chi tiết commit vừa tạo"*
     - 🌿 `git branch` — *"Chạy git branch -a"*
   - **⚡ Thao tác nhanh (Actions):**
     - 💾 **Smart Commit** — *"Tạo git commit với message mô tả ngắn gọn thay đổi vừa làm"*
     - ↩️ **Undo All** — *"Chạy git restore . để hoàn tác các thay đổi chưa commit"*
     - 📦 **Git Stash** — *"Chạy git stash để tạm cất các thay đổi"*
3. **Custom Input Bar:**
   - Text input with a suffix "Gửi" button allowing the user to type and send any arbitrary Git prompt without scrolling or opening the full chat keyboard.
4. **Action Mechanics:**
   - **Tap card/chip:** Directly injects the prompt into the webview input and auto-submits.
   - **Secondary icon button ("Chèn"):** Inserts the command into the chat input without submitting, allowing user customization.

### 2.3 Injection Engine
- Reuses `RemoteScreen._injectPromptIntoWebView(prompt, autoSubmit: true/false)`, which targets textarea, contenteditable, or input, dispatches DOM input events, and triggers the send button or Enter key.

---

## 3. Implementation Plan Summary
1. Create `lib/screens/remote/widgets/git_actions_modal.dart`.
2. Update `lib/screens/remote/widgets/floating_capsule.dart` to include `onGitActions` callback and button.
3. Update `lib/screens/remote/remote_screen.dart` to wire up `_openGitActionsModal` and invoke `_injectPromptIntoWebView`.
4. Add automated tests in `test/git_actions_modal_test.dart`.
5. Run `flutter analyze`, `flutter test`, and `flutter build apk --debug`.
