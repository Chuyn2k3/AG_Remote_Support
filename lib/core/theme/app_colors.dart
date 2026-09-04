import 'package:flutter/material.dart';

/// Hệ thống màu sắc chuẩn VHT Modern Minimalism
/// Tuyệt đối không sử dụng màu đỏ thương hiệu Viettel
class AppColors {
  // Brand & Accent Colors (Thay thế màu đỏ bằng Tím AI & Cyan)
  static const Color brandPrimary = Color(0xFF7A5AF8);       // Modern AI Violet
  static const Color brandPrimaryLight = Color(0xFF9B82F9);
  static const Color accentCyan = Color(0xFF0284C7);          // Tech Blue / In-Progress

  // Trạng thái chuẩn VHT (Trang 8 & 10 tài liệu VHT)
  static const Color stateSuccess = Color(0xFF10B981);        // Xanh lá Online / Hoàn thành
  static const Color stateWarning = Color(0xFFFEBA00);        // Vàng Cảnh báo / Keep Awake
  static const Color stateNeutral = Color(0xFF64748B);        // Xám trạng thái Idle

  // Surfaces & Backgrounds
  static const Color bgDark = Color(0xFF0F1012);              // Nền chính tối sâu
  static const Color surfaceDark = Color(0xFF18191B);         // Nền thẻ card
  static const Color surfaceDarkElevated = Color(0xFF222428); // Nền dialog / menu nổi
  static const Color borderSubtle = Color(0xFF2F3033);        // Viền ngăn cách 1px
  static const Color borderHighlight = Color(0xFF383A40);

  // Typography Colors
  static const Color textPrimary = Color(0xFFF8FAFC);         // Trắng ngà
  static const Color textSecondary = Color(0xFF94A3B8);       // Xám bạc
  static const Color textMuted = Color(0xFF64748B);           // Xám tối
}
