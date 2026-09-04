import 'package:flutter/material.dart';

/// Hệ thống bảng màu Apple Cupertino Clean Style (HIG)
/// Hỗ trợ cả 2 giao diện Light Mode và Dark Mode.
/// Tuyệt đối không sử dụng bất kỳ sắc thái nào của màu đỏ Viettel (#EE0033, #61000E).
class AppColors {
  // --- LIGHT MODE PALETTE (Apple iOS Standard) ---
  static const Color lightBackground = Color(0xFFF2F2F7);       // System Grouped Background
  static const Color lightSurface = Color(0xFFFFFFFF);          // Card/Elevated White
  static const Color lightSurfaceSecondary = Color(0xFFE5E5EA); // Secondary Fill Gray
  static const Color lightPrimary = Color(0xFF007AFF);          // Apple System Blue
  static const Color lightPrimaryLight = Color(0xFFEBF5FF);     // Soft Blue Tint for Badges
  static const Color lightBorder = Color(0xFFE5E5EA);           // Subtle 1px Divider/Border
  static const Color lightTextPrimary = Color(0xFF000000);      // Pure Black
  static const Color lightTextSecondary = Color(0xFF8E8E93);    // System Gray (Secondary)
  static const Color lightTextMuted = Color(0xFFAEAEB2);        // System Gray 2

  // --- DARK MODE PALETTE (Apple OLED Dark) ---
  static const Color darkBackground = Color(0xFF000000);        // True OLED Black
  static const Color darkSurface = Color(0xFF1C1C1E);           // Apple Dark Elevated Card
  static const Color darkSurfaceSecondary = Color(0xFF2C2C2E);  // Secondary Dark Fill
  static const Color darkPrimary = Color(0xFF0A84FF);           // Apple Dark System Blue
  static const Color darkPrimaryLight = Color(0x260A84FF);      // 15% opacity Dark Blue
  static const Color darkBorder = Color(0xFF2C2C2E);            // Subtle 1px Dark Border
  static const Color darkTextPrimary = Color(0xFFFFFFFF);       // Pure White
  static const Color darkTextSecondary = Color(0xFF8E8E93);     // System Gray
  static const Color darkTextMuted = Color(0xFF636366);         // System Gray 3

  // --- SEMANTIC STATUS COLORS ---
  static const Color statusSuccess = Color(0xFF34C759);         // Apple System Green Light
  static const Color statusSuccessDark = Color(0xFF30D158);     // Apple System Green Dark
  static const Color statusWarning = Color(0xFFFF9F0A);         // Apple System Orange
  static const Color statusNeutral = Color(0xFF8E8E93);         // Apple Neutral Gray

  // --- BACKWARD COMPATIBILITY ALIASES ---
  static const Color brandPrimary = lightPrimary;
  static const Color brandPrimaryLight = Color(0xFF5AC8FA);
  static const Color accentCyan = Color(0xFF007AFF);
  static const Color stateSuccess = statusSuccess;
  static const Color stateWarning = statusWarning;
  static const Color stateNeutral = statusNeutral;
  static const Color bgDark = darkBackground;
  static const Color surfaceDark = darkSurface;
  static const Color surfaceDarkElevated = darkSurfaceSecondary;
  static const Color borderSubtle = darkBorder;
  static const Color borderHighlight = Color(0xFF3A3A3C);
  static const Color textPrimary = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted = darkTextMuted;
}
