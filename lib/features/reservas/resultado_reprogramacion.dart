import 'data/reserva_reprogramada.dart';

/// Cómo terminó el intento de cambiar la fecha, la hora o el servicio.
enum TipoResultadoReprogramacion {
  /// La API movió la reserva; quedó Pendiente (T18).
  reprogramada,

  /// 409: la reserva ya no se puede cambiar (estado o plazo).
  noReprogramable,

  /// 404: la reserva ya no existe para este cliente.
  noDisponible,
}

class ResultadoReprogramacion {
  const ResultadoReprogramacion.reprogramada(ReservaReprogramada this.reserva)
    : tipo = TipoResultadoReprogramacion.reprogramada,
      mensaje = null;

  const ResultadoReprogramacion.noReprogramable(String this.mensaje)
    : tipo = TipoResultadoReprogramacion.noReprogramable,
      reserva = null;

  const ResultadoReprogramacion.noDisponible(String this.mensaje)
    : tipo = TipoResultadoReprogramacion.noDisponible,
      reserva = null;

  final TipoResultadoReprogramacion tipo;
  final ReservaReprogramada? reserva;
  final String? mensaje;
}
