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

extension CFThemeContext on BuildContext {
  ThemeData get cfTheme => Theme.of(this);

  bool get cfIsDark => cfTheme.brightness == Brightness.dark;

  Color get cfPrimary => cfTheme.colorScheme.primary;
  Color get cfBackground => cfTheme.scaffoldBackgroundColor;
  Color get cfSurface => cfTheme.colorScheme.surface;
  Color get cfTextPrimary =>
      cfTheme.textTheme.bodyLarge?.color ??
      (cfIsDark ? Colors.white : CFColors.textPrimary);
  Color get cfTextSecondary =>
      cfTheme.textTheme.bodyMedium?.color ??
      (cfIsDark ? const Color(0xFFCBD5E1) : CFColors.textSecondary);
  Color get cfBorder => cfIsDark ? const Color(0xFF243041) : CFColors.softGray;
  Color get cfMutedSurface =>
      cfIsDark ? const Color(0xFF162133) : const Color(0xFFF8FAFD);
  Color get cfSoftSurface =>
      cfIsDark ? const Color(0xFF101A2A) : CFColors.background;
  Color get cfPrimaryTint =>
      cfPrimary.withValues(alpha: cfIsDark ? 0.18 : 0.10);
  Color get cfPrimaryTintStrong =>
      cfPrimary.withValues(alpha: cfIsDark ? 0.24 : 0.16);
  Color get cfShadow => Colors.black.withValues(alpha: cfIsDark ? 0.24 : 0.05);
  Color get cfOnPrimaryStrong =>
      cfIsDark ? const Color(0xFF0B1220) : Colors.white;
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: CFColors.primary,
    brightness: Brightness.light,
  ).copyWith(primary: CFColors.primary, surface: CFColors.surface);

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
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: CFColors.surface,
      selectedItemColor: CFColors.primary,
      unselectedItemColor: CFColors.textSecondary,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
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
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CFColors.primary,
        side: const BorderSide(color: CFColors.softGray),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return CFColors.primary;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return CFColors.primary.withValues(alpha: 0.42);
        }
        return CFColors.softGray;
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: CFColors.primary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CFColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CFColors.softGray),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CFColors.softGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: CFColors.primary, width: 1.4),
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
    dividerTheme: const DividerThemeData(
      color: CFColors.softGray,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF8FAFD),
      selectedColor: CFColors.primary.withValues(alpha: 0.12),
      disabledColor: const Color(0xFFF8FAFD),
      side: const BorderSide(color: CFColors.softGray),
      shape: const StadiumBorder(),
      labelStyle: const TextStyle(
        color: CFColors.textSecondary,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: CFColors.primary,
      unselectedLabelColor: CFColors.textSecondary,
      indicatorColor: CFColors.primary,
      dividerColor: CFColors.softGray,
    ),
  );
}

ThemeData buildDarkAppTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: CFColors.primary,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF8EA8D6),
        surface: const Color(0xFF121826),
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
    scaffoldBackgroundColor: const Color(0xFF0B1220),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B1220),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF121826),
      selectedItemColor: Color(0xFF8EA8D6),
      unselectedItemColor: Color(0xFF94A3B8),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF121826),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: Color(0xFF243041)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF8EA8D6),
        foregroundColor: const Color(0xFF0B1220),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF8EA8D6),
        side: const BorderSide(color: Color(0xFF243041)),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF8EA8D6);
        }
        return const Color(0xFFE2E8F0);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF8EA8D6).withValues(alpha: 0.42);
        }
        return const Color(0xFF243041);
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: const Color(0xFF8EA8D6)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF121826),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF243041)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF243041)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF8EA8D6), width: 1.4),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
      side: const BorderSide(color: Color(0xFF243041)),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF8EA8D6);
        }
        return const Color(0xFF121826);
      }),
      checkColor: WidgetStateProperty.all(const Color(0xFF0B1220)),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.white),
      bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFCBD5E1)),
      bodySmall: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFF243041),
      thickness: 1,
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Color(0xFF162133),
      selectedColor: Color(0xFF21314B),
      disabledColor: Color(0xFF162133),
      side: BorderSide(color: Color(0xFF243041)),
      shape: StadiumBorder(),
      labelStyle: TextStyle(
        color: Color(0xFFCBD5E1),
        fontWeight: FontWeight.w700,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Color(0xFF8EA8D6),
      unselectedLabelColor: Color(0xFF94A3B8),
      indicatorColor: Color(0xFF8EA8D6),
      dividerColor: Color(0xFF243041),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF121826)),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF121826),
      surfaceTintColor: Colors.transparent,
    ),
  );
}
