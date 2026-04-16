import 'package:flutter/material.dart';

const kGradientStart = Color(0xFF0D7377);
const kGradientEnd   = Color(0xFF14BDAC);
const kAccent        = Color(0xFF1DE9B6);
const kSurface       = Color(0xFFF4F7F6);
const kCardBg        = Colors.white;

const kHeaderGradient = LinearGradient(
  colors: [Color(0xFF0A5C61), Color(0xFF14BDAC)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const kAvatarGradients = [
  LinearGradient(colors: [Color(0xFF6A11CB), Color(0xFF2575FC)]),
  LinearGradient(colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)]),
  LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)]),
  LinearGradient(colors: [Color(0xFFFC466B), Color(0xFF3F5EFB)]),
  LinearGradient(colors: [Color(0xFFF7971E), Color(0xFFFFD200)]),
  LinearGradient(colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)]),
  LinearGradient(colors: [Color(0xFFEB5757), Color(0xFF000000)]),
  LinearGradient(colors: [Color(0xFF43E97B), Color(0xFF38F9D7)]),
];

LinearGradient avatarGradient(String seed) =>
    kAvatarGradients[seed.codeUnits.fold(0, (a, b) => a + b) % kAvatarGradients.length];

ThemeData buildTheme() {
  final cs = ColorScheme.fromSeed(
    seedColor: kGradientStart,
    brightness: Brightness.light,
  ).copyWith(
    primary: kGradientStart,
    secondary: kAccent,
    surface: kSurface,
  );
  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: kSurface,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: kCardBg,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: kGradientStart, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kGradientStart,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: kGradientStart.withOpacity(0.1),
      labelStyle: const TextStyle(color: kGradientStart, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
    ),
  );
}
