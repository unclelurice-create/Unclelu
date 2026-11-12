import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pilihan warna aksen (urutan = indeks yang disimpan di shared_preferences)
const accentColors = <Color>[
  Color(0xFFD92D20), // Merah (default)
  Color(0xFFE8590C), // Oranye
  Color(0xFFC2185B), // Magenta
  Color(0xFF12805C), // Hijau
  Color(0xFF2B59C3), // Biru
];

/// Token warna kustom di luar ColorScheme.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color accent;
  final Color accentTint; // aksen pucat
  final Color bg;
  final Color card;
  final Color ink;
  final Color ink2;
  final Color line;
  final Color seg;
  final Color hero;
  final Color ok;
  final Color okTint;
  final Color warn;
  final Color warnTint;
  final Color blue;
  final Color blueTint;
  final bool dark;
  const AppTokens({required this.accent, required this.accentTint, required this.bg, required this.card, required this.ink, required this.ink2, required this.line, required this.seg, required this.hero, required this.ok, required this.okTint, required this.warn, required this.warnTint, required this.blue, required this.blueTint, required this.dark});

  factory AppTokens.of(Color accent, bool dark) {
    final card = dark ? const Color(0xFF211716) : Colors.white;
    return AppTokens(
      accent: accent,
      accentTint: Color.lerp(card, accent, dark ? 0.18 : 0.11)!,
      bg: dark ? const Color(0xFF150F0E) : const Color(0xFFFFFBFA),
      card: card,
      ink: dark ? const Color(0xFFFAF1EE) : const Color(0xFF1F1412),
      ink2: dark ? const Color(0xFFB5A5A1) : const Color(0xFF6B5E5A),
      line: dark ? const Color(0xFF342725) : const Color(0xFFF0E6E3),
      seg: dark ? const Color(0xFF2A1E1C) : const Color(0xFFF7EFEC),
      hero: dark ? const Color(0xFF2C1F1D) : const Color(0xFF1F1412),
      ok: dark ? const Color(0xFF4ADE9A) : const Color(0xFF12805C),
      okTint: dark ? const Color(0xFF12301F) : const Color(0xFFE6F6EF),
      warn: dark ? const Color(0xFFFDB022) : const Color(0xFFB54708),
      warnTint: dark ? const Color(0xFF3A2410) : const Color(0xFFFFF3E0),
      blue: dark ? const Color(0xFF8FB0FF) : const Color(0xFF2B59C3),
      blueTint: dark ? const Color(0xFF1B2640) : const Color(0xFFE8EEFB),
      dark: dark,
    );
  }

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) => (other is AppTokens && t > .5) ? other : this;
}

extension TokensX on BuildContext {
  AppTokens get tk => Theme.of(this).extension<AppTokens>()!;
}

ThemeData buildTheme(Color accent, {required bool dark}) {
  final t = AppTokens.of(accent, dark);
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: dark ? Brightness.dark : Brightness.light).copyWith(
    primary: accent,
    onPrimary: Colors.white,
    surface: t.card,
    onSurface: t.ink,
    error: accent,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: dark ? Brightness.dark : Brightness.light);
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: t.ink, displayColor: t.ink);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
  return base.copyWith(
    scaffoldBackgroundColor: t.bg,
    extensions: [t],
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.5),
      titleMedium: text.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: text.bodySmall?.copyWith(fontSize: 13, color: t.ink2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: border(t.line),
      enabledBorder: border(t.line),
      focusedBorder: border(accent, 1.5),
      hintStyle: TextStyle(color: t.ink2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent, textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.card,
      showDragHandle: true,
      dragHandleColor: t.line,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.ink,
      contentTextStyle: GoogleFonts.plusJakartaSans(color: t.bg, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerColor: t.line,
  );
}
