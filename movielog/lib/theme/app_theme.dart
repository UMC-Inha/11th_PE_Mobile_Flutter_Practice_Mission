import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: 'Manrope',
    scaffoldBackgroundColor: AppColors.warmWhite,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      primary: AppColors.violet,
      onPrimary: AppColors.white,
      surface: AppColors.warmWhite,
      onSurface: AppColors.black,
    ),
    textTheme: const TextTheme(
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.warmWhite,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: const Color(0x33000000),
      indicatorColor: AppColors.lavender,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? AppColors.violetDark : AppColors.darkGray,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 13,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.violetDark : AppColors.darkGray,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.warmWhite,
      foregroundColor: AppColors.black,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.warmWhite,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    ),
  );
}
