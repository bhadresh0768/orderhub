import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData lightTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme),
    colorScheme: base.colorScheme.copyWith(
      primary: const Color(0xFF0F3D3E),
      secondary: const Color(0xFFF2A154),
      surface: Colors.white,
      onSurface: const Color(0xFF414143),
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF414143),
      elevation: 0,
    ),
  );
}

ThemeData darkTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    textTheme: GoogleFonts.spaceGroteskTextTheme(base.textTheme),
    colorScheme: base.colorScheme.copyWith(
      primary: const Color(0xFF9ED2C6),
      secondary: const Color(0xFFF2A154),
      surface: const Color(0xFF1C2321),
    ),
  );
}
