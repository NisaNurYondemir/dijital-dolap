import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF22305A); // ana renk (indigo mürekkep)
  static const chalk = Color(0xFFF5F6F8); // arka plan
  static const thread = Color(0xFFF2B84B); // vurgu (iplik sarısı)
  static const slate = Color(0xFF5B6478); // ikincil metin
  static const line = Color(0xFFE2E5EB); // ince çizgiler
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.ink,
      onPrimary: Colors.white,
      secondary: AppColors.thread,
      onSecondary: AppColors.ink,
      surface: Colors.white,
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.chalk,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.chalk,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: const TextTheme(
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.slate),
        bodySmall: TextStyle(fontSize: 12, color: AppColors.slate),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.thread,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.all(
          const IconThemeData(color: AppColors.ink),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        showCheckmark: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.thread,
        foregroundColor: AppColors.ink,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
