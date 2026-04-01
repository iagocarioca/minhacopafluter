import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF18C76F);
  static const Color accent = Color(0xFF10B861);
  static const Color warning = Color(0xFFE9A73E);
  static const Color info = Color(0xFF3B82F6);
  static const Color background = Color(0xFFF4F6F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0F3F6);
  static const Color surfaceBorder = Color(0xFFE3E8EE);
  static const Color surfaceBorderSoft = Color(0xEDF0F4F8);
  static const Color surfaceBorderStrong = Color(0xFFD6DEE8);
  static const Color textPrimary = Color(0xFF121821);
  static const Color textMuted = Color(0xFF7A8597);
  static const Color textSoft = Color(0xFF576173);
  static const Color glow = Color(0x3318C76F);
  static const Color glassTop = Color(0xFFF6F8FA);
  static const Color glassBottom = Color(0xFFF0F4F7);

  static ThemeData light() {
    final baseTextTheme = ThemeData.light().textTheme;
    final textTheme = GoogleFonts.robotoTextTheme(baseTextTheme)
        .copyWith(
          displayLarge: GoogleFonts.poppins(
            textStyle: baseTextTheme.displayLarge,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
          displayMedium: GoogleFonts.poppins(
            textStyle: baseTextTheme.displayMedium,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.18,
          ),
          displaySmall: GoogleFonts.poppins(
            textStyle: baseTextTheme.displaySmall,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.16,
          ),
          titleLarge: GoogleFonts.poppins(
            textStyle: baseTextTheme.titleLarge,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.14,
          ),
          titleMedium: GoogleFonts.poppins(
            textStyle: baseTextTheme.titleMedium,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.12,
          ),
          titleSmall: GoogleFonts.poppins(
            textStyle: baseTextTheme.titleSmall,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        )
        .apply(bodyColor: textPrimary, displayColor: textPrimary);
    final scheme = const ColorScheme.light(
      primary: primary,
      secondary: accent,
      onSecondary: Colors.white,
      surface: surface,
      error: Color(0xFFE14A52),
      onPrimary: Colors.white,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme.copyWith(
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF12171D),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.45,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceBorderSoft),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textSoft),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFF11161C),
        indicatorColor: const Color(0x3018C76F),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white);
          }
          return const IconThemeData(color: Color(0xFF93A0B2));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : const Color(0xFF93A0B2),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F3F6),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: textTheme.labelMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: surfaceBorder),
        selectedColor: const Color(0x2418C76F),
        backgroundColor: surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0x6E18C76F);
            }
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFF10B861);
            }
            return primary;
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: const WidgetStatePropertyAll(Color(0x2218C76F)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(textPrimary),
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: surfaceBorder)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFFE9EEF3);
            }
            return surface;
          }),
          overlayColor: const WidgetStatePropertyAll(Color(0x1818C76F)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0x2418C76F);
            }
            return surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return primary;
            }
            return textMuted;
          }),
          side: const WidgetStatePropertyAll(BorderSide(color: surfaceBorder)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textMuted,
        textColor: textPrimary,
      ),
      dividerTheme: const DividerThemeData(color: surfaceBorder, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF1D232B),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }
}
