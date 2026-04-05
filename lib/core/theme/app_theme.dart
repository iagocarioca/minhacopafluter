import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Spacing scale
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space14 = 14;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;

  // Radius scale
  static const double radiusSm = 10;
  static const double radiusMd = 12;
  static const double radiusLg = 14;
  static const double radiusXl = 16;

  // Control heights
  static const double controlHeightSm = 40;
  static const double controlHeightMd = 44;
  static const double controlHeightLg = 50;

  static const Color primary = Color(0xFF17A76F);
  static const Color accent = Color(0xFF116066);
  static const Color warning = Color(0xFFE9A73E);
  static const Color info = Color(0xFF3B82F6);
  static const Color background = Color(0xFFF2F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEAF3EF);
  static const Color surfaceBorder = Color(0xFFD9E8E1);
  static const Color surfaceBorderSoft = Color(0xEDE2ECE7);
  static const Color surfaceBorderStrong = Color(0xFFC6DCD2);
  static const Color textPrimary = Color(0xFF102C2B);
  static const Color textMuted = Color(0xFF6A7D7B);
  static const Color textSoft = Color(0xFF4F6462);
  static const Color glow = Color(0x3317A76F);
  static const Color glassTop = Color(0xFFF4F9F7);
  static const Color glassBottom = Color(0xFFEAF3F0);

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
        backgroundColor: const Color(0xFF0F5C57),
        foregroundColor: Colors.white,
        elevation: 1.25,
        scrolledUnderElevation: 1.25,
        shadowColor: const Color(0x1F000000),
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
        backgroundColor: const Color(0xFF0F5C57),
        indicatorColor: const Color(0x3036AB79),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white);
          }
          return const IconThemeData(color: Color(0xFFC5DBD6));
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? Colors.white : const Color(0xFFC5DBD6),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F6F4),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textMuted),
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSoft),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: textTheme.labelMedium?.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: surfaceBorder),
        selectedColor: const Color(0x2417A76F),
        backgroundColor: surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0x6E17A76F);
            }
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFF116066);
            }
            return primary;
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          minimumSize: const WidgetStatePropertyAll(Size(64, controlHeightLg)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: space16, vertical: 12),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          overlayColor: const WidgetStatePropertyAll(Color(0x2217A76F)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(textPrimary),
          minimumSize: const WidgetStatePropertyAll(Size(64, controlHeightLg)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: space16, vertical: 12),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: surfaceBorder)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFFE5F0EC);
            }
            return surface;
          }),
          overlayColor: const WidgetStatePropertyAll(Color(0x1817A76F)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(0, controlHeightSm),
          padding: const EdgeInsets.symmetric(horizontal: space12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
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
              return const Color(0x2417A76F);
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
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.05,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
          ),
          overlayColor: const WidgetStatePropertyAll(Color(0x14000000)),
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
        backgroundColor: const Color(0xFF134642),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
    );
  }
}
