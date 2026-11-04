import 'package:flutter/widgets.dart';

/// Espacios compartidos (escala de 4/8). Las pantallas no usan otros valores.
abstract final class Espacios {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Margen lateral de las pantallas.
  static const pantalla = EdgeInsets.symmetric(horizontal: l, vertical: l);
}

/// Radios de esquina compartidos.
abstract final class Radios {
  /// Chips pequeños, miniaturas.
  static const double s = 8;

  /// Botones, campos y avisos.
  static const double m = 12;

  /// Tarjetas y diálogos.
  static const double l = 16;

  static const campo = BorderRadius.all(Radius.circular(m));
  static const tarjeta = BorderRadius.all(Radius.circular(l));
}

/// Tamaños compartidos de controles e íconos.
abstract final class Medidas {
  /// Alto mínimo de los botones principales (≥ 48 dp de área táctil).
  static const double boton = 52;

  /// Área táctil mínima de cualquier control.
  static const double tactil = 48;

  static const double iconoEstado = 56;
  static const double miniatura = 56;
  static const double logo = 72;
}
