import 'package:flutter/material.dart';

class CFColors {
  static const Color primary = Color(0xFF27426B); // #27426B
  static const Color primaryDark = Color(0xFF1D3353);
  static const Color primaryLight = Color(0xFF3D5D8F);

  static const Color background = Color(0xFFF6F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color softGray = Color(0xFFE6EAF2);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: CFColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: CFColors.primary,
    surface: CFColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    scaffoldBackgroundColor: CFColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: CFColors.background,
      foregroundColor: CFColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: CFColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: CFColors.softGray),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CFColors.primary,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      side: const BorderSide(color: CFColors.softGray),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return CFColors.primary;
        return CFColors.surface;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: CFColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: CFColors.textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: CFColors.textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: CFColors.textSecondary),
    ),
    dividerTheme: const DividerThemeData(color: CFColors.softGray, thickness: 1),
  );
}
