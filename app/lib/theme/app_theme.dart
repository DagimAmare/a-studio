import 'package:flutter/material.dart';

import 'colors.dart';

/// Amharic glyphs fall back to the bundled Noto Ethiopic families, so a line
/// mixing English and Amharic renders cleanly everywhere.
const List<String> kSansFallback = ['NotoSansEthiopic'];
const List<String> kSerifFallback = ['NotoSansEthiopic'];

/// Interface and body text: DM Sans, sturdy and easy to read at small sizes.
const String kSans = 'DMSans';

/// Headlines, names and big numbers: Lora SemiBold, a readable serif.
const String kDisplay = 'Lora';

/// The A STUDIO wordmark and the "A." mark only (Bodoni Moda, bold cut).
const String kWordmark = 'Bodoni';

TextStyle displayStyle(double size,
    {Color color = AppColors.espresso,
    FontStyle style = FontStyle.normal,
    String family = kDisplay,
    double height = 1.12,
    double letterSpacing = 0}) {
  return TextStyle(
    fontFamily: family,
    fontFamilyFallback: kSerifFallback,
    fontWeight: FontWeight.w600,
    fontStyle: style,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
  );
}

TextStyle labelCaps(
    {Color color = AppColors.taupe, double size = 12, double spacing = 2.4}) {
  return TextStyle(
    fontFamily: kSans,
    fontFamilyFallback: kSansFallback,
    fontWeight: FontWeight.w600,
    fontSize: size,
    letterSpacing: spacing,
    color: color,
  );
}

ThemeData buildAppTheme({
  StudioPalette? palette,
  StudioAccent? accent,
  StudioFont? font,
}) {
  final p = palette ?? kStudioPalettes.first;
  final a = accent ?? kStudioAccents.first;
  final f = font ?? kStudioFonts.first;
  final primary = p.dark ? a.onDark : a.onLight;
  final onPrimary =
      ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
          ? Colors.white
          : AppColors.espresso;

  final scheme = ColorScheme(
    brightness: p.dark ? Brightness.dark : Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    secondary: p.dark ? AppColors.noirText : AppColors.espresso,
    onSecondary: p.dark ? AppColors.noir : AppColors.milk,
    tertiary: AppColors.champagne,
    onTertiary: AppColors.espresso,
    error: p.dark ? AppColors.noirRose : AppColors.rouge,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.text,
    surfaceContainerHighest: p.dark ? const Color(0xFF2A221E) : AppColors.oat,
    onSurfaceVariant: p.muted,
    outline: p.line,
    outlineVariant: p.line,
  );

  TextStyle body(double size, {FontWeight w = FontWeight.w400, Color? c}) =>
      TextStyle(
        fontFamily: kSans,
        fontFamilyFallback: kSansFallback,
        fontSize: size,
        fontWeight: w,
        height: 1.4,
        color: c ?? p.text,
      );
  TextStyle head(double size) => TextStyle(
        fontFamily: f.family,
        fontFamilyFallback: kSerifFallback,
        fontStyle: f.style,
        fontWeight: FontWeight.w600,
        fontSize: size,
        height: 1.12,
        color: p.text,
      );

  final textTheme = TextTheme(
    displayLarge: head(56),
    displayMedium: head(44),
    displaySmall: head(36),
    headlineLarge: head(32),
    headlineMedium: head(28),
    headlineSmall: head(24),
    titleLarge: body(20, w: FontWeight.w500),
    titleMedium: body(16, w: FontWeight.w500),
    titleSmall: body(14, w: FontWeight.w500),
    bodyLarge: body(16),
    bodyMedium: body(15),
    bodySmall: body(13, c: p.muted),
    labelLarge: body(15, w: FontWeight.w500),
    labelMedium: body(13, w: FontWeight.w500),
    labelSmall: body(12, w: FontWeight.w500, c: p.muted),
  );

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    fontFamily: kSans,
    fontFamilyFallback: kSansFallback,
    textTheme: textTheme,
    dividerColor: p.line,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: body(18, w: FontWeight.w500),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: shape,
        textStyle: body(15, w: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.dark ? AppColors.noirText : AppColors.espresso,
        foregroundColor: p.dark ? AppColors.noir : AppColors.milk,
        elevation: 0,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: shape,
        textStyle: body(15, w: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        side: BorderSide(color: p.dark ? AppColors.noirMuted : AppColors.cocoa),
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: shape,
        textStyle: body(15, w: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: body(15, w: FontWeight.w500),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.dark ? const Color(0xFF2A221E) : AppColors.white,
      selectedColor: p.dark ? const Color(0xFF3A2E28) : AppColors.petal,
      side: BorderSide(color: p.line),
      labelStyle: body(14, w: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: body(15, c: p.muted),
      hintStyle: body(15, c: p.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.espresso,
      contentTextStyle: body(14, c: AppColors.milk),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.dark ? const Color(0xFF3A2E28) : AppColors.petal,
      labelTextStyle: WidgetStatePropertyAll(body(12, w: FontWeight.w500)),
      height: 66,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.text,
      unselectedLabelColor: p.muted,
      indicatorColor: primary,
      labelStyle: body(14, w: FontWeight.w600),
      unselectedLabelStyle: body(14, w: FontWeight.w500),
      dividerColor: p.line,
      tabAlignment: TabAlignment.start,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    visualDensity: VisualDensity.standard,
  );
}
