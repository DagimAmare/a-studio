import 'package:flutter/material.dart';

/// The A Studio palette (see the plan's Brand section). Contrast checked
/// against WCAG AA for every text use.
class AppColors {
  AppColors._();

  static const milk = Color(0xFFFAF6F1);
  static const oat = Color(0xFFEFE6DC);
  static const latte = Color(0xFFD8C3AE);
  static const petal = Color(0xFFF1D3D3);
  static const rouge = Color(0xFF9E2A3A);
  static const cocoa = Color(0xFF3A2A24);
  static const espresso = Color(0xFF1E1512);
  static const champagne = Color(0xFFC8A97E);
  static const taupe = Color(0xFF7A6A60);
  static const sage = Color(0xFF4F6B4A);
  static const honey = Color(0xFF8A6420);
  static const line = Color(0xFFE7DCCF);
  static const white = Color(0xFFFFFFFF);

  static const noir = Color(0xFF14100E);
  static const noirSurface = Color(0xFF1F1916);
  static const noirText = Color(0xFFF3EBE3);
  static const noirMuted = Color(0xFFB9AA9E);
  static const noirRose = Color(0xFFE08A96);
}

/// A page palette for an artist's studio page ("Decor your studio").
class StudioPalette {
  final String id;
  final String label;
  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color line;
  final bool dark;

  const StudioPalette({
    required this.id,
    required this.label,
    required this.background,
    required this.surface,
    required this.text,
    required this.muted,
    required this.line,
    this.dark = false,
  });
}

class StudioAccent {
  final String id;
  final String label;
  final Color onLight;
  final Color onDark;
  const StudioAccent(this.id, this.label, this.onLight, this.onDark);
}

class StudioFont {
  final String id;
  final String label;
  final String family;
  final FontStyle style;
  const StudioFont(this.id, this.label, this.family, this.style);
}

const List<StudioPalette> kStudioPalettes = [
  StudioPalette(
    id: 'milk',
    label: 'Milk',
    background: AppColors.milk,
    surface: AppColors.white,
    text: AppColors.espresso,
    muted: AppColors.taupe,
    line: AppColors.line,
  ),
  StudioPalette(
    id: 'latte',
    label: 'Latte',
    background: AppColors.oat,
    surface: Color(0xFFF8F2EA),
    text: Color(0xFF2B1F1A),
    muted: Color(0xFF6E5E53),
    line: AppColors.latte,
  ),
  StudioPalette(
    id: 'rouge',
    label: 'Blush',
    background: Color(0xFFF7EDEC),
    surface: AppColors.white,
    text: Color(0xFF2A1215),
    muted: Color(0xFF75575A),
    line: Color(0xFFEBD3D4),
  ),
  StudioPalette(
    id: 'noir',
    label: 'Noir',
    background: AppColors.noir,
    surface: AppColors.noirSurface,
    text: AppColors.noirText,
    muted: AppColors.noirMuted,
    line: Color(0xFF3A2E28),
    dark: true,
  ),
];

const List<StudioAccent> kStudioAccents = [
  StudioAccent('rouge', 'Rouge', AppColors.rouge, AppColors.noirRose),
  StudioAccent('cocoa', 'Cocoa', AppColors.cocoa, Color(0xFFD9BFAE)),
  StudioAccent('champagne', 'Champagne', Color(0xFF8C6A3E), AppColors.champagne),
  StudioAccent('rose', 'Rose', Color(0xFFA8455E), Color(0xFFF0A3B4)),
  StudioAccent('sage', 'Sage', AppColors.sage, Color(0xFFA9C4A2)),
  StudioAccent('plum', 'Plum', Color(0xFF6B2D5C), Color(0xFFD7A3C9)),
];

/// Ids stay as first released so saved studio pages keep their choice.
const List<StudioFont> kStudioFonts = [
  StudioFont('bodoni', 'Classic', 'Lora', FontStyle.normal),
  StudioFont('italic', 'Editorial', 'Lora', FontStyle.italic),
  StudioFont('jost', 'Modern', 'DMSans', FontStyle.normal),
];

StudioPalette paletteById(String? id) =>
    kStudioPalettes.firstWhere((p) => p.id == id, orElse: () => kStudioPalettes.first);
StudioAccent accentById(String? id) =>
    kStudioAccents.firstWhere((a) => a.id == id, orElse: () => kStudioAccents.first);
StudioFont fontById(String? id) =>
    kStudioFonts.firstWhere((f) => f.id == id, orElse: () => kStudioFonts.first);
