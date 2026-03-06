// lib/utils/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── 컬러 팔레트 (미니멀 클린) ──
  static const Color primary = Color(0xFF1A73E8);        // 메인 블루
  static const Color primaryLight = Color(0xFFE8F0FE);  // 연한 블루 bg
  static const Color profit = Color(0xFF1A8754);        // 수익 그린
  static const Color profitLight = Color(0xFFE6F4EA);   // 연한 그린 bg
  static const Color loss = Color(0xFFD93025);          // 손실 레드
  static const Color lossLight = Color(0xFFFCE8E6);     // 연한 레드 bg
  static const Color warning = Color(0xFFE37400);       // 경고 오렌지
  static const Color warningLight = Color(0xFFFEF3E2);  // 연한 오렌지
  static const Color textPrimary = Color(0xFF202124);   // 주 텍스트
  static const Color textSecondary = Color(0xFF5F6368); // 부 텍스트
  static const Color textTertiary = Color(0xFF9AA0A6);  // 3차 텍스트
  static const Color divider = Color(0xFFE8EAED);       // 구분선
  static const Color background = Color(0xFFF8F9FA);    // 배경
  static const Color surface = Color(0xFFFFFFFF);       // 카드 배경
  static const Color surfaceVariant = Color(0xFFF1F3F4); // 연한 카드

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.notoSansKrTextTheme().copyWith(
        displayLarge: GoogleFonts.notoSansKr(
          fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
        displayMedium: GoogleFonts.notoSansKr(
          fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        headlineLarge: GoogleFonts.notoSansKr(
          fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium: GoogleFonts.notoSansKr(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        headlineSmall: GoogleFonts.notoSansKr(
          fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: GoogleFonts.notoSansKr(
          fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.notoSansKr(
          fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
        bodyLarge: GoogleFonts.notoSansKr(
          fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: GoogleFonts.notoSansKr(
          fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary),
        bodySmall: GoogleFonts.notoSansKr(
          fontSize: 12, fontWeight: FontWeight.w400, color: textTertiary),
        labelLarge: GoogleFonts.notoSansKr(
          fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary),
        labelMedium: GoogleFonts.notoSansKr(
          fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
        labelSmall: GoogleFonts.notoSansKr(
          fontSize: 11, fontWeight: FontWeight.w400, color: textTertiary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: divider,
        titleTextStyle: GoogleFonts.notoSansKr(
          fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: divider, thickness: 1, space: 0),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.notoSansKr(
              fontSize: 11, fontWeight: FontWeight.w600, color: primary);
          }
          return GoogleFonts.notoSansKr(
            fontSize: 11, fontWeight: FontWeight.w400, color: textTertiary);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 22);
          }
          return const IconThemeData(color: textTertiary, size: 22);
        }),
        elevation: 0,
        shadowColor: divider,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleFonts.notoSansKr(
            fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariant,
        labelStyle: GoogleFonts.notoSansKr(
          fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }
}
