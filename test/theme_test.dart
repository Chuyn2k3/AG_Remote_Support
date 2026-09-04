import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_support/core/theme/app_colors.dart';
import 'package:antigravity_support/core/theme/app_theme.dart';

void main() {
  test('AppColors Light and Dark tokens must not contain Viettel red', () {
    const viettelRedPrimary = 0xFFEE0033;
    const viettelRedDark = 0xFF61000E;

    final allColors = [
      AppColors.lightBackground,
      AppColors.lightSurface,
      AppColors.lightPrimary,
      AppColors.darkBackground,
      AppColors.darkSurface,
      AppColors.darkPrimary,
      AppColors.statusSuccess,
      AppColors.statusSuccessDark,
    ];

    for (final color in allColors) {
      expect(color.value, isNot(equals(viettelRedPrimary)));
      expect(color.value, isNot(equals(viettelRedDark)));
    }
  });

  test('AppTheme provides valid lightTheme and darkTheme', () {
    final light = AppTheme.lightTheme;
    final dark = AppTheme.darkTheme;

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(dark.scaffoldBackgroundColor, AppColors.darkBackground);
  });
}
