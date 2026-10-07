import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dark Ink & Ember — canvas matches app icon ink; ember path accent.
abstract final class ZipColors {
  /// App canvas / scaffold (app icon background).
  static const ink = Color(0xFF0F172A);

  /// Primary text / icons on dark surfaces.
  static const onInk = Color(0xFFF8FAFC);

  /// Secondary / muted text.
  static const inkSoft = Color(0xFF94A3B8);

  /// Alias of canvas (atmosphere / scaffold).
  static const mist = Color(0xFF0F172A);

  /// Tracks, quiet fills, outline variant.
  static const mistDeep = Color(0xFF334155);

  /// Secondary panels / parked rows.
  static const paper = Color(0xFF243044);

  /// Raised cards / board / chips.
  static const wall = Color(0xFF1E293B);

  static const ember = Color(0xFFFF6B2C);
  static const emberDeep = Color(0xFFE85A1C);

  /// Soft ember wash (dark tint, not peach).
  static const emberSoft = Color(0xFF3A241C);

  static const success = Color(0xFF2DD4BF);

  /// Profile sound-effects accent (same hue as [success]).
  static const teal = success;
  static const successSoft = Color(0xFF134E4A);

  /// Path Words accent (sky, distinct from Zip ember).
  static const sky = Color(0xFF38BDF8);

  /// Filled controls — dark enough for white label contrast.
  static const skyDeep = Color(0xFF0369A1);
  static const skySoft = Color(0xFF163044);

  /// Zip number markers (readable on dark board).
  static const number = Color(0xFFFB7185);

  static const outline = Color(0xFF475569);
  static const outlineQuiet = Color(0xFF334155);

  /// Gradients & glows for elevated modern UI
  static const emberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF7E40), Color(0xFFE85A1C)],
  );

  static const skyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
  );

  static const successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF059669)],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF223049), Color(0xFF182234)],
  );

  static const emberGlow = Color(0x4DFF6B2C);
  static const skyGlow = Color(0x4D38BDF8);
  static const glassBorder = Color(0x3394A3B8);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ZipColors.ink,
  );

  final textTheme = GoogleFonts.lexendTextTheme(
    base.textTheme,
  ).apply(bodyColor: ZipColors.onInk, displayColor: ZipColors.onInk);

  return base.copyWith(
    colorScheme: const ColorScheme.dark(
      primary: ZipColors.ember,
      onPrimary: Colors.white,
      primaryContainer: ZipColors.emberSoft,
      onPrimaryContainer: ZipColors.ember,
      secondary: ZipColors.wall,
      onSecondary: ZipColors.onInk,
      tertiary: ZipColors.success,
      onTertiary: ZipColors.ink,
      surface: ZipColors.wall,
      onSurface: ZipColors.onInk,
      onSurfaceVariant: ZipColors.inkSoft,
      surfaceContainerHighest: ZipColors.paper,
      outline: ZipColors.outline,
      outlineVariant: ZipColors.outlineQuiet,
      error: Color(0xFFF87171),
      onError: ZipColors.ink,
    ),
    textTheme: textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
      ),
      displaySmall: textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: ZipColors.onInk,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: GoogleFonts.lexend(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: ZipColors.onInk,
      ),
      iconTheme: const IconThemeData(color: ZipColors.onInk),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: ZipColors.wall,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ZipColors.ember,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.lexend(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ZipColors.onInk,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        side: const BorderSide(color: ZipColors.outline, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.lexend(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ZipColors.inkSoft,
        textStyle: GoogleFonts.lexend(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ZipColors.wall,
      hintStyle: const TextStyle(color: ZipColors.inkSoft),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZipColors.outlineQuiet),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZipColors.outlineQuiet),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ZipColors.ember, width: 1.5),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ZipColors.ember,
      linearTrackColor: ZipColors.mistDeep,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return ZipColors.ember;
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return ZipColors.inkSoft;
        }),
        elevation: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return 3;
          }
          return 0;
        }),
        shadowColor: const WidgetStatePropertyAll(ZipColors.emberGlow),
        side: const WidgetStatePropertyAll(BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.lexend(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            fontSize: 13.5,
            letterSpacing: 0.2,
          );
        }),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ZipColors.wall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: ZipColors.outlineQuiet),
      ),
      elevation: 16,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ZipColors.wall,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dividerColor: ZipColors.outlineQuiet,
  );
}
