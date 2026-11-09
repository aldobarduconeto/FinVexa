import 'package:flutter/material.dart';

import 'package:finvexa/models/preferences.dart';

ThemeData buildAppTheme(AppPreferences prefs, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xff0f1520) : const Color(0xfff4f6fa);
  final surface = dark ? const Color(0xff192230) : Colors.white;
  final border = dark ? const Color(0xff2b3241) : const Color(0xffe6e9f0);
  final text = dark ? const Color(0xffedf1fa) : const Color(0xff202b41);
  final muted = dark ? const Color(0xffa3afc4) : const Color(0xff53647c);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: prefs.accentColor,
        brightness: brightness,
      ).copyWith(
        primary: dark
            ? Color.lerp(prefs.accentColor, Colors.white, .42)
            : prefs.accentColor,
        onPrimary: dark ? const Color(0xff10203c) : Colors.white,
        surface: surface,
        onSurface: text,
        onSurfaceVariant: muted,
        outlineVariant: border,
      );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    fontFamily: 'NotoSans',
    visualDensity: prefs.compact
        ? VisualDensity.compact
        : VisualDensity.standard,
    textTheme: TextTheme(
      bodyMedium: TextStyle(fontSize: 14, color: text, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, color: muted, height: 1.5),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: text,
        letterSpacing: -.5,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: text,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff141925) : const Color(0xfffafbfe),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      labelStyle: TextStyle(fontSize: 12, color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: shape,
        side: BorderSide(color: border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shape,
        textStyle: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(
        dark ? const Color(0xff212838) : const Color(0xfff7f9fc),
      ),
      headingTextStyle: TextStyle(
        fontSize: 11,
        color: muted,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: TextStyle(fontSize: 12, color: text),
      dividerThickness: .5,
      columnSpacing: 32,
      horizontalMargin: 18,
      dataRowMinHeight: prefs.compact ? 42 : 52,
      dataRowMaxHeight: prefs.compact ? 54 : 68,
      headingRowHeight: 48,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      elevation: 0,
      indicatorColor: scheme.primary.withValues(alpha: .12),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 10, color: text),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.primary.withValues(alpha: .08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 450),
    ),
  );
}
