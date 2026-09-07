# Thiết kế Kỹ thuật: Khắc phục triệt để lỗi Màn hình đen trên WebView (Xiaomi HyperOS / Android 14)

## 1. Bối cảnh & Vấn đề

Khi người dùng mở phiên làm việc từ xa (`RemoteScreen`), màn hình hiển thị vòng quay loading trong giây lát rồi toàn bộ nội dung chuyển sang màu đen sì (`#000000`).

### Nguyên nhân gốc rễ
1. **`BackdropFilter` trong `FloatingCapsule` (`floating_capsule.dart:82, 114`):**
   - Flutter Engine trên Android khi render `BackdropFilter` (chức năng làm mờ hậu cảnh) đè lên một Android PlatformView (`SurfaceView` do `useHybridComposition: true`) sẽ cố gắng chụp buffer đồ họa bên dưới.
   - Do `SurfaceView` là layer native do Android `SurfaceFlinger` quản lý độc lập ngoài Skia/Impeller canvas, thao tác này làm hỏng compositor layer của Flutter trên Xiaomi HyperOS/MIUI và khiến toàn bộ RenderView biến thành màu đen đặc (Flutter bug #55786 & #101684).
   - Widget `FloatingCapsule` luôn hiện diện trên màn hình ở layer trên cùng (`Stack`), dẫn đến việc ngay khi loading kết thúc, lỗi màn hình đen lập tức xuất hiện.
2. **`BackdropFilter` trong `GitActionsModal` (`git_actions_modal.dart:155`):**
   - Tương tự, nếu mở modal Git Actions thì màn hình cũng có nguy cơ bị đen layer.
3. **`transparentBackground: true` trong `InAppWebViewSettings` (`remote_screen.dart:1284`):**
   - Khi kích hoạt với `useHybridComposition: true`, `SurfaceView` native của Android có nền mặc định là màu đen. Nếu WebView có các vùng trong suốt trong quá trình nạp CSS/iframe thì nền đen này sẽ bị lộ ra ngoài.

---

## 2. Giải pháp Kỹ thuật

### 2.1. Loại bỏ hoàn toàn `BackdropFilter` khỏi các widget nổi trên WebView

#### A. Widget `FloatingCapsule` (`lib/screens/remote/widgets/floating_capsule.dart`)
- **Gỡ bỏ:**
  - `import 'dart:ui';`
  - Widget `BackdropFilter` và `ClipRRect` bọc capsule chính (dòng 80–83).
  - Widget `BackdropFilter` bọc menu mở rộng `_buildMoreMenu()` (dòng 114–117).
- **Cập nhật giao diện:**
  - Thiết lập nền màu đặc tối sâu: `color: const Color(0xFF16161A).withOpacity(0.96)`.
  - Giữ nguyên viền nổi mờ: `border: Border.all(color: Colors.white.withOpacity(0.18), width: 0.8)`.
  - Giữ nguyên đổ bóng: `boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 18, offset: Offset(0, 5))]`.
  - Đảm bảo thanh điều khiển nổi bật, chuẩn phong cách Apple HIG Dark UI mà không gây áp lực lên GPU.

#### B. Modal `GitActionsModal` (`lib/screens/remote/widgets/git_actions_modal.dart`)
- **Gỡ bỏ:**
  - Widget `BackdropFilter` (dòng 155).
- **Cập nhật:**
  - Giữ `ClipRRect` bo tròn góc đỉnh.
  - Sử dụng nền màu đặc `surfaceColor` theo theme hiện tại.

### 2.2. Hiệu chỉnh cấu hình `InAppWebViewSettings` (`lib/screens/remote/remote_screen.dart`)
- **Cập nhật:**
  - Đổi `transparentBackground: false` (dòng 1284).
  - Giữ nguyên `useHybridComposition: true` để tận dụng kiến trúc `SurfaceView` chuẩn tương thích với chip GPU Mali / Adreno và phần mềm Xiaomi HyperOS.

---

## 3. Kế hoạch Kiểm thử & Xác minh

1. **Kiểm tra biên dịch & phân tích mã nguồn:**
   - Chạy `flutter analyze` đảm bảo không có warning hay unused imports.
2. **Kiểm thử trực tiếp trên thiết bị (Xiaomi 21081111RG):**
   - Build và chạy ứng dụng trên máy thật qua ADB.
   - Mở màn hình `RemoteScreen`, xác nhận:
     - Màn hình tải xong hiển thị đầy đủ giao diện Antigravity Web UI (28 conversations, khung nhập liệu, thanh công cụ).
     - Thanh `FloatingCapsule` hiển thị rõ ràng, kéo thả bình thường, mở menu phụ không bị lỗi màn hình đen.
     - Dùng ADB `screencap` chụp lại màn hình thực tế để lưu bằng chứng nghiệm thu.
