import 'package:flutter/material.dart';

import 'tokens.dart';

/// アプリ全体のテーマ（仕様書 §12 / Figma Foundations）。
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: TofuTokens.brandPrimary,
      primary: TofuTokens.brandPrimary,
      onPrimary: TofuTokens.brandOnPrimary,
      secondary: TofuTokens.brandAccent,
      surface: TofuTokens.bgCanvas,
      onSurface: TofuTokens.textPrimary,
      error: TofuTokens.dangerBgStrong,
      onError: TofuTokens.brandOnPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: TofuTokens.bgCanvas,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      fontFamily: TofuTokens.fontFamily,
      textTheme: const TextTheme(
        displayLarge: TofuTextStyles.displayL,
        displayMedium: TofuTextStyles.displayM,
        displaySmall: TofuTextStyles.displayS,
        headlineLarge: TofuTextStyles.h1,
        headlineMedium: TofuTextStyles.h2,
        headlineSmall: TofuTextStyles.h3,
        titleLarge: TofuTextStyles.h4,
        titleMedium: TofuTextStyles.bodyLgBold,
        titleSmall: TofuTextStyles.bodyMdBold,
        bodyLarge: TofuTextStyles.bodyLg,
        bodyMedium: TofuTextStyles.bodyMd,
        bodySmall: TofuTextStyles.bodySm,
        labelLarge: TofuTextStyles.bodyMdBold,
        labelMedium: TofuTextStyles.bodySmBold,
        labelSmall: TofuTextStyles.captionBold,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TofuTokens.bgCanvas,
        foregroundColor: TofuTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TofuTextStyles.h4,
      ),
      cardTheme: CardThemeData(
        color: TofuTokens.bgCanvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
          side: const BorderSide(color: TofuTokens.borderSubtle),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: TofuTokens.borderSubtle,
        thickness: TofuTokens.strokeHairline,
        space: TofuTokens.space5,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TofuTokens.brandPrimary,
          foregroundColor: TofuTokens.brandOnPrimary,
          minimumSize: const Size(TofuTokens.touchMin, TofuTokens.touchMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space7,
            vertical: TofuTokens.space5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
          ),
          textStyle: TofuTextStyles.bodyLgBold,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: TofuTokens.textPrimary,
          minimumSize: const Size(TofuTokens.touchMin, TofuTokens.touchMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space7,
            vertical: TofuTokens.space5,
          ),
          side: const BorderSide(color: TofuTokens.borderDefault),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TofuTokens.radiusLg),
          ),
          textStyle: TofuTextStyles.bodyLgBold,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TofuTokens.textLink,
          minimumSize: const Size(TofuTokens.touchMin, TofuTokens.touchMin),
          padding: const EdgeInsets.symmetric(
            horizontal: TofuTokens.space5,
            vertical: TofuTokens.space4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
          ),
          textStyle: TofuTextStyles.bodyMdBold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TofuTokens.bgCanvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space5,
          vertical: TofuTokens.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
          borderSide: const BorderSide(color: TofuTokens.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
          borderSide: const BorderSide(color: TofuTokens.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
          borderSide: const BorderSide(color: TofuTokens.borderFocus, width: 2),
        ),
        labelStyle: TofuTextStyles.bodyMd,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: TofuTokens.bgSurface,
        selectedColor: TofuTokens.brandPrimarySubtleStrong,
        labelStyle: TofuTextStyles.bodyMd,
        side: const BorderSide(color: TofuTokens.borderSubtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: TofuTokens.space5,
          vertical: TofuTokens.space3,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: TofuTokens.bgCanvas,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TofuTokens.radiusXl),
        ),
        titleTextStyle: TofuTextStyles.h3,
        contentTextStyle: TofuTextStyles.bodyMd,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: TofuTokens.bgInverse,
        contentTextStyle: TofuTextStyles.bodyMd.copyWith(
          color: TofuTokens.textInverse,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TofuTokens.radiusMd),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((
          states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return TofuTokens.brandOnPrimary;
          }
          return TofuTokens.gray100;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((
          states,
        ) {
          if (states.contains(WidgetState.selected)) {
            return TofuTokens.brandPrimary;
          }
          return TofuTokens.gray400;
        }),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: TofuTokens.brandPrimary,
        unselectedLabelColor: TofuTokens.textTertiary,
        indicatorColor: TofuTokens.brandPrimary,
        labelStyle: TofuTextStyles.bodyLgBold,
        unselectedLabelStyle: TofuTextStyles.bodyLg,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: TofuTokens.textSecondary,
        titleTextStyle: TofuTextStyles.bodyLg,
        subtitleTextStyle: TofuTextStyles.bodySm,
        contentPadding: EdgeInsets.symmetric(
          horizontal: TofuTokens.space5,
          vertical: TofuTokens.space3,
        ),
      ),
    );
  }

  static ThemeData dark() {
    // 学祭POSは屋外明所運用が中心。darkは緊急用フォールバック。
    return light().copyWith(brightness: Brightness.dark);
  }
}
