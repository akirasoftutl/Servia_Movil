import 'package:flutter/material.dart';

import 'colores_servia.dart';
import 'tokens.dart';

/// Fuente de la app (Plus Jakarta Sans, OFL; assets/fonts). Es la de los
/// títulos del panel, para que app y panel se parezcan.
const fuenteServia = 'PlusJakartaSans';

/// Escala tipográfica de Servia. Los colores salen del esquema.
TextTheme _textos(ColorScheme c) {
  TextStyle estilo(
    double tamano,
    FontWeight peso, {
    double alto = 1.3,
    double espacio = 0,
    Color? color,
  }) => TextStyle(
    fontFamily: fuenteServia,
    fontSize: tamano,
    fontWeight: peso,
    height: alto,
    letterSpacing: espacio,
    color: color ?? c.onSurface,
  );

  return TextTheme(
    displayLarge: estilo(48, FontWeight.w700, alto: 1.1, espacio: -1),
    displayMedium: estilo(40, FontWeight.w700, alto: 1.1, espacio: -0.8),
    displaySmall: estilo(32, FontWeight.w700, alto: 1.15, espacio: -0.6),
    headlineLarge: estilo(28, FontWeight.w700, alto: 1.2, espacio: -0.5),
    headlineMedium: estilo(26, FontWeight.w700, alto: 1.2, espacio: -0.5),
    headlineSmall: estilo(22, FontWeight.w700, alto: 1.25, espacio: -0.3),
    titleLarge: estilo(19, FontWeight.w700, alto: 1.3, espacio: -0.2),
    titleMedium: estilo(16, FontWeight.w600, alto: 1.35),
    titleSmall: estilo(14, FontWeight.w600, alto: 1.35),
    bodyLarge: estilo(16, FontWeight.w400, alto: 1.5),
    bodyMedium: estilo(14, FontWeight.w400, alto: 1.45),
    bodySmall: estilo(
      13,
      FontWeight.w400,
      alto: 1.4,
      color: c.onSurfaceVariant,
    ),
    labelLarge: estilo(15, FontWeight.w600, alto: 1.25, espacio: 0.1),
    labelMedium: estilo(13, FontWeight.w600, alto: 1.25, espacio: 0.1),
    labelSmall: estilo(12, FontWeight.w600, alto: 1.25, espacio: 0.2),
  );
}

/// Tema central de la app del cliente (Material 3, modo claro).
ThemeData temaServia() {
  const c = ColoresServia.esquema;
  final textos = _textos(c);
  const formaBoton = RoundedRectangleBorder(borderRadius: Radios.campo);
  const tamanoBoton = Size(64, Medidas.boton);
  const rellenoBoton = EdgeInsets.symmetric(horizontal: Espacios.xl);
  OutlineInputBorder bordeCampo(Color color, [double ancho = 1]) =>
      OutlineInputBorder(
        borderRadius: Radios.campo,
        borderSide: BorderSide(color: color, width: ancho),
      );

  // Botón principal: mismo aspecto para FilledButton y ElevatedButton.
  final principal = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? c.onSurface.withValues(alpha: 0.12)
          : c.primary,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? c.onSurface.withValues(alpha: 0.38)
          : c.onPrimary,
    ),
    overlayColor: WidgetStatePropertyAll(c.onPrimary.withValues(alpha: 0.12)),
    elevation: const WidgetStatePropertyAll(0),
    minimumSize: const WidgetStatePropertyAll(tamanoBoton),
    padding: const WidgetStatePropertyAll(rellenoBoton),
    shape: const WidgetStatePropertyAll(formaBoton),
    textStyle: WidgetStatePropertyAll(textos.labelLarge),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: c,
    fontFamily: fuenteServia,
    textTheme: textos,
    scaffoldBackgroundColor: ColoresServia.fondo,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    extensions: const [ColoresSemanticos.servia],
    appBarTheme: AppBarThemeData(
      backgroundColor: ColoresServia.fondo,
      foregroundColor: c.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: Espacios.l,
      titleTextStyle: textos.titleLarge,
      iconTheme: IconThemeData(color: c.onSurface),
      actionsIconTheme: IconThemeData(color: c.onSurfaceVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(style: principal),
    elevatedButtonTheme: ElevatedButtonThemeData(style: principal),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: tamanoBoton,
        padding: rellenoBoton,
        shape: formaBoton,
        side: BorderSide(color: c.outline),
        textStyle: textos.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size(Medidas.tactil, Medidas.tactil),
        padding: const EdgeInsets.symmetric(horizontal: Espacios.m),
        shape: formaBoton,
        textStyle: textos.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(Medidas.tactil, Medidas.tactil),
        foregroundColor: c.onSurfaceVariant,
      ),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: c.surface,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Espacios.l,
        vertical: Espacios.m + 2,
      ),
      border: bordeCampo(c.outline),
      enabledBorder: bordeCampo(c.outline),
      disabledBorder: bordeCampo(c.outlineVariant),
      focusedBorder: bordeCampo(c.primary, 2),
      errorBorder: bordeCampo(c.error),
      focusedErrorBorder: bordeCampo(c.error, 2),
      hintStyle: textos.bodyLarge?.copyWith(color: c.onSurfaceVariant),
      labelStyle: textos.bodyLarge?.copyWith(color: c.onSurfaceVariant),
      floatingLabelStyle: textos.bodyMedium?.copyWith(
        color: c.primary,
        fontWeight: FontWeight.w600,
      ),
      helperStyle: textos.bodySmall,
      errorStyle: textos.bodySmall?.copyWith(color: c.error),
      prefixIconColor: c.onSurfaceVariant,
      suffixIconColor: c.onSurfaceVariant,
      errorMaxLines: 3,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: Radios.tarjeta,
        side: BorderSide(color: c.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.onSurfaceVariant,
      textColor: c.onSurface,
      titleTextStyle: textos.titleMedium,
      subtitleTextStyle: textos.bodyMedium?.copyWith(color: c.onSurfaceVariant),
      leadingAndTrailingTextStyle: textos.titleMedium,
      contentPadding: const EdgeInsets.symmetric(horizontal: Espacios.l),
      minVerticalPadding: Espacios.m,
      horizontalTitleGap: Espacios.m,
      shape: const RoundedRectangleBorder(borderRadius: Radios.tarjeta),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceContainerHigh,
      selectedColor: c.primaryContainer,
      labelStyle: textos.labelMedium?.copyWith(color: c.onSurface),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: Espacios.s),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: Radios.tarjeta),
      titleTextStyle: textos.titleLarge,
      contentTextStyle: textos.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.inverseSurface,
      contentTextStyle: textos.bodyMedium?.copyWith(color: c.onInverseSurface),
      actionTextColor: c.inversePrimary,
      shape: const RoundedRectangleBorder(borderRadius: Radios.campo),
      elevation: 2,
    ),
    // Morado para el indicador de carga.
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ColoresServia.morado,
      circularTrackColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(
      color: c.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.primaryContainer,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(textos.labelMedium),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      dayStyle: textos.bodyMedium,
      weekdayStyle: textos.labelMedium?.copyWith(color: c.onSurfaceVariant),
      headerHelpStyle: textos.labelLarge,
      todayBorder: BorderSide(color: c.primary),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? c.onPrimary
            : s.contains(WidgetState.disabled)
            ? c.onSurface.withValues(alpha: 0.38)
            : c.primary,
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(textStyle: textos.bodyLarge),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.primary,
      selectionColor: c.primaryContainer,
      selectionHandleColor: c.primary,
    ),
  );
}
