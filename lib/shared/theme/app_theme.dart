import 'package:flutter/material.dart';

const primaryColor = Color(0xFF0F766E);
const incomeColor = Color(0xFF15803D);
const expenseColor = Color(0xFFB42318);
const inkColor = Color(0xFF1F2A24);
const mutedColor = Color(0xFF69746B);
const borderColor = Color(0xFFE4E0D4);
const softTeal = Color(0xFFE6F3F0);
const amberAccent = Color(0xFFF4B942);
const appBackground = Color(0xFFF7F6F0);

@immutable
class EazyColors extends ThemeExtension<EazyColors> {
  const EazyColors({
    required this.ink,
    required this.muted,
    required this.border,
    required this.surface,
    required this.surfaceAlt,
    required this.hero,
    required this.income,
    required this.expense,
    required this.warning,
    required this.shadow,
  });

  final Color ink;
  final Color muted;
  final Color border;
  final Color surface;
  final Color surfaceAlt;
  final Color hero;
  final Color income;
  final Color expense;
  final Color warning;
  final Color shadow;

  @override
  EazyColors copyWith({
    Color? ink,
    Color? muted,
    Color? border,
    Color? surface,
    Color? surfaceAlt,
    Color? hero,
    Color? income,
    Color? expense,
    Color? warning,
    Color? shadow,
  }) {
    return EazyColors(
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      border: border ?? this.border,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      hero: hero ?? this.hero,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  EazyColors lerp(ThemeExtension<EazyColors>? other, double t) {
    if (other is! EazyColors) return this;
    return EazyColors(
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      hero: Color.lerp(hero, other.hero, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension EazyTheme on BuildContext {
  EazyColors get eazyColors => Theme.of(this).extension<EazyColors>()!;
}

ThemeData buildAppTheme() {
  return _buildTheme(
    brightness: Brightness.light,
    background: appBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      surface: appBackground,
    ),
    eazyColors: const EazyColors(
      ink: inkColor,
      muted: mutedColor,
      border: borderColor,
      surface: Colors.white,
      surfaceAlt: Color(0xFFF0ECE0),
      hero: Color(0xFFE6F3F0),
      income: incomeColor,
      expense: expenseColor,
      warning: amberAccent,
      shadow: Color(0x1F2F3A33),
    ),
  );
}

ThemeData buildAppDarkTheme() {
  return _buildTheme(
    brightness: Brightness.dark,
    background: const Color(0xFF111411),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF42C7B8),
      brightness: Brightness.dark,
      primary: const Color(0xFF5ED0C2),
      surface: const Color(0xFF111411),
    ),
    eazyColors: const EazyColors(
      ink: Color(0xFFEAF0E9),
      muted: Color(0xFFA8B2AA),
      border: Color(0xFF2C352F),
      surface: Color(0xFF1A1F1B),
      surfaceAlt: Color(0xFF242A25),
      hero: Color(0xFF163B36),
      income: Color(0xFF68D391),
      expense: Color(0xFFFF8A80),
      warning: Color(0xFFF6C95F),
      shadow: Color(0x66000000),
    ),
  );
}

ThemeData _buildTheme({
  required Brightness brightness,
  required Color background,
  required ColorScheme colorScheme,
  required EazyColors eazyColors,
}) {
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    colorScheme: colorScheme,
    fontFamily: 'Noto Sans Thai',
    fontFamilyFallback: const ['Tahoma', 'Arial', 'Roboto'],
    scaffoldBackgroundColor: background,
    useMaterial3: true,
    extensions: [eazyColors],
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: eazyColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: eazyColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: eazyColors.surface,
      indicatorColor:
          colorScheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: eazyColors.ink, fontWeight: FontWeight.w700),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colorScheme.primary
              : eazyColors.muted,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: isDark ? const Color(0xFF06201D) : Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: eazyColors.border),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: eazyColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: eazyColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: eazyColors.surface,
      labelStyle: TextStyle(color: eazyColors.muted),
      hintStyle: TextStyle(color: eazyColors.muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: eazyColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
  );
}
