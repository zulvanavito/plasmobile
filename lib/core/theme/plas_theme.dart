import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:plasmobile/core/theme/plas_tokens.dart';

ThemeData buildPlasTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: PlasColors.brandPrimary,
    onPrimary: Colors.white,
    secondary: PlasColors.brandHover,
    onSecondary: Colors.white,
    error: PlasColors.errorBorder,
    onError: Colors.white,
    surface: PlasColors.bgSurface,
    onSurface: PlasColors.textPrimary,
    surfaceContainerLowest: PlasColors.bgSurface,
    surfaceContainerLow: PlasColors.bgCanvas,
    surfaceContainer: PlasColors.bgSubtle,
    outline: PlasColors.borderInteractive,
    outlineVariant: PlasColors.borderDivider,
  );

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(PlasRadii.md),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: PlasTypography.fontSans,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: PlasColors.bgCanvas,
    dividerColor: PlasColors.borderSubtle,
    appBarTheme: AppBarTheme(
      backgroundColor: PlasColors.bgSurface,
      foregroundColor: PlasColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: PlasTypography.heading,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: PlasColors.bgSurface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      shape: const Border(
        bottom: BorderSide(color: PlasColors.borderSubtle),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PlasColors.brandPrimary,
      linearTrackColor: PlasColors.borderSubtle,
    ),
    dividerTheme: const DividerThemeData(
      color: PlasColors.borderSubtle,
      thickness: 1,
      space: 1,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: PlasColors.brandPrimary,
      selectionHandleColor: PlasColors.brandPrimary,
      selectionColor: Color(0x331D4ED8),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PlasColors.textPrimary,
      contentTextStyle: PlasTypography.body.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PlasRadii.md),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    cardTheme: CardThemeData(
      color: PlasColors.bgSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PlasRadii.lg),
        side: const BorderSide(color: PlasColors.borderDivider),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PlasColors.bgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PlasRadii.xl),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PlasColors.bgSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PlasRadii.xl),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: PlasSpacing.space4,
            vertical: PlasSpacing.space3,
          ),
        ),
        shape: WidgetStatePropertyAll(buttonShape),
        textStyle: WidgetStatePropertyAll(PlasTypography.label),
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return PlasColors.disabledBg;
          }
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return PlasColors.brandHover;
          }
          return PlasColors.brandPrimary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return PlasColors.disabledText;
          }
          return Colors.white;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(color: PlasColors.focusLight, width: 2);
          }
          return BorderSide.none;
        }),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: PlasSpacing.space4,
            vertical: PlasSpacing.space3,
          ),
        ),
        shape: WidgetStatePropertyAll(buttonShape),
        textStyle: WidgetStatePropertyAll(PlasTypography.label),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return PlasColors.disabledText;
          }
          return PlasColors.textPrimary;
        }),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return PlasColors.disabledBg;
          }
          return PlasColors.bgSurface;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: PlasColors.disabledBorder);
          }
          if (states.contains(WidgetState.focused)) {
            return const BorderSide(color: PlasColors.focusLight, width: 2);
          }
          return const BorderSide(color: PlasColors.borderInteractive);
        }),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        textStyle: WidgetStatePropertyAll(PlasTypography.label),
        foregroundColor: const WidgetStatePropertyAll(PlasColors.brandPrimary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PlasColors.bgSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PlasSpacing.space4,
        vertical: PlasSpacing.space3,
      ),
      labelStyle: PlasTypography.body,
      hintStyle: PlasTypography.body.copyWith(color: PlasColors.textMuted),
      errorStyle: PlasTypography.caption.copyWith(color: PlasColors.errorText),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PlasRadii.md),
        borderSide: const BorderSide(color: PlasColors.borderInteractive),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PlasRadii.md),
        borderSide: const BorderSide(color: PlasColors.borderInteractive),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PlasRadii.md),
        borderSide: const BorderSide(color: PlasColors.brandPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PlasRadii.md),
        borderSide: const BorderSide(color: PlasColors.errorBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PlasRadii.md),
        borderSide: const BorderSide(color: PlasColors.errorBorder, width: 2),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PlasRadii.md),
        borderSide: const BorderSide(color: PlasColors.disabledBorder),
      ),
    ),
    textTheme: TextTheme(
      headlineMedium: PlasTypography.display,
      titleLarge: PlasTypography.heading,
      titleMedium: PlasTypography.title,
      bodyMedium: PlasTypography.body,
      labelLarge: PlasTypography.label,
      bodySmall: PlasTypography.caption,
    ),
  );
}
