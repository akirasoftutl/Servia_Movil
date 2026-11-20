import 'package:flutter/material.dart';

/// Paleta de Servia para la app del cliente (pendiente de aprobación del PO).
///
/// El naranja de marca `#E27441` es el del panel (docs/arquitectura.md) y el
/// del logo. Con texto blanco llega solo a 3.08:1, así que se usa en el logo,
/// los indicadores y los acentos grandes; los botones rellenos y el texto de
/// acción usan [primario], de la misma familia, que llega a 5.46:1 con blanco.
/// Los contrastes calculados están en el PR de la issue Servia_Movil#40.
abstract final class ColoresServia {
  /// Naranja de marca: logo, indicadores de carga, acentos grandes.
  static const marca = Color(0xFFE27441);

  /// Naranja tostado para botones rellenos, enlaces y texto de acción.
  static const primario = Color(0xFFB04A22);
  static const enPrimario = Color(0xFFFFFFFF);
  static const primarioContenedor = Color(0xFFFCE6DA);
  static const enPrimarioContenedor = Color(0xFF5C2410);

  /// Neutros cálidos.
  static const fondo = Color(0xFFFBF8F5);
  static const superficie = Color(0xFFFFFFFF);
  static const superficieSuave = Color(0xFFF6F1EC);
  static const superficieHundida = Color(0xFFF0E9E3);
  static const superficieMasHundida = Color(0xFFEAE1DA);
  static const texto = Color(0xFF241A14);
  static const textoSuave = Color(0xFF6B5E55);

  /// Borde de campos y controles (≥ 3:1 sobre blanco y sobre [fondo]).
  static const bordeCampo = Color(0xFF968579);

  /// Borde decorativo de tarjetas y separadores.
  static const borde = Color(0xFFE8DED6);

  /// Secundario: café cálido para elementos de apoyo.
  static const secundario = Color(0xFF6E5A4E);
  static const secundarioContenedor = Color(0xFFF1E4DA);
  static const enSecundarioContenedor = Color(0xFF3A2C23);

  /// Semánticos (texto sobre su fondo ≥ 4.5:1).
  static const exito = Color(0xFF1F7A4A);
  static const exitoFondo = Color(0xFFE6F4EC);
  static const aviso = Color(0xFF85550A);
  static const avisoFondo = Color(0xFFFFF3DC);
  static const error = Color(0xFFB42F3E);
  static const errorFondo = Color(0xFFFDECEE);
  static const enErrorFondo = Color(0xFF7A1724);

  /// Avisos flotantes (snackbars).
  static const inverso = Color(0xFF2F2621);
  static const enInverso = Color(0xFFFBF1EA);
  static const primarioInverso = Color(0xFFFFB693);

  static const esquema = ColorScheme(
    brightness: Brightness.light,
    primary: primario,
    onPrimary: enPrimario,
    primaryContainer: primarioContenedor,
    onPrimaryContainer: enPrimarioContenedor,
    secondary: secundario,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: secundarioContenedor,
    onSecondaryContainer: enSecundarioContenedor,
    tertiary: exito,
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: exitoFondo,
    onTertiaryContainer: Color(0xFF0F4A2B),
    error: error,
    onError: Color(0xFFFFFFFF),
    errorContainer: errorFondo,
    onErrorContainer: enErrorFondo,
    surface: superficie,
    onSurface: texto,
    onSurfaceVariant: textoSuave,
    surfaceDim: superficieMasHundida,
    surfaceBright: superficie,
    surfaceContainerLowest: superficie,
    surfaceContainerLow: fondo,
    surfaceContainer: superficieSuave,
    surfaceContainerHigh: superficieHundida,
    surfaceContainerHighest: superficieMasHundida,
    outline: bordeCampo,
    outlineVariant: borde,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: inverso,
    onInverseSurface: enInverso,
    inversePrimary: primarioInverso,
    // Sin tinte de elevación: las superficies conservan su color cálido.
    surfaceTint: Colors.transparent,
  );
}

/// Colores semánticos para chips y avisos (acepta reservas, pendiente, etc.).
@immutable
class ColoresSemanticos extends ThemeExtension<ColoresSemanticos> {
  const ColoresSemanticos({
    required this.exito,
    required this.exitoFondo,
    required this.aviso,
    required this.avisoFondo,
    required this.neutro,
    required this.neutroFondo,
  });

  static const servia = ColoresSemanticos(
    exito: ColoresServia.exito,
    exitoFondo: ColoresServia.exitoFondo,
    aviso: ColoresServia.aviso,
    avisoFondo: ColoresServia.avisoFondo,
    neutro: ColoresServia.textoSuave,
    neutroFondo: ColoresServia.superficieHundida,
  );

  /// Los del tema; si la pantalla se monta sin el tema de Servia (pruebas),
  /// se usan los de la paleta.
  static ColoresSemanticos de(BuildContext context) =>
      Theme.of(context).extension<ColoresSemanticos>() ?? servia;

  final Color exito;
  final Color exitoFondo;
  final Color aviso;
  final Color avisoFondo;
  final Color neutro;
  final Color neutroFondo;

  @override
  ColoresSemanticos copyWith({
    Color? exito,
    Color? exitoFondo,
    Color? aviso,
    Color? avisoFondo,
    Color? neutro,
    Color? neutroFondo,
  }) => ColoresSemanticos(
    exito: exito ?? this.exito,
    exitoFondo: exitoFondo ?? this.exitoFondo,
    aviso: aviso ?? this.aviso,
    avisoFondo: avisoFondo ?? this.avisoFondo,
    neutro: neutro ?? this.neutro,
    neutroFondo: neutroFondo ?? this.neutroFondo,
  );

  @override
  ColoresSemanticos lerp(ColoresSemanticos? other, double t) {
    if (other == null) return this;
    return ColoresSemanticos(
      exito: Color.lerp(exito, other.exito, t)!,
      exitoFondo: Color.lerp(exitoFondo, other.exitoFondo, t)!,
      aviso: Color.lerp(aviso, other.aviso, t)!,
      avisoFondo: Color.lerp(avisoFondo, other.avisoFondo, t)!,
      neutro: Color.lerp(neutro, other.neutro, t)!,
      neutroFondo: Color.lerp(neutroFondo, other.neutroFondo, t)!,
    );
  }
}
