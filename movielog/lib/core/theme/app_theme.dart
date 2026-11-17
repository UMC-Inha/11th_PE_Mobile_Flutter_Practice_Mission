import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF6750A4);
  static const surface = Color(0xFFFAF9F5);
  static const text = Color(0xFF242126);
  static const mutedText = Color(0xFF6E6875);
  static const error = Color(0xFFB3261E);
  static const success = Color(0xFF1B7F3B);

  /// 비활성·통신 중 버튼 배경. 입력창 테두리와 같은 회보라 계열이다.
  static const disabled = Color(0xFFD7D1DC);
}

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    fontFamilyFallback: const ['Apple SD Gothic Neo', 'Noto Sans KR'],
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.surface,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD7D1DC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD7D1DC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    ),
  );
}
