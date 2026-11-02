/// Cómo terminó el intento de reservar un horario.
enum ResultadoReserva {
  /// La API creó la reserva (ya se mostró la confirmación).
  enviada,

  /// 409: el horario ya no está libre; hay que elegir otro.
  horarioOcupado,

  /// El cliente salió sin enviar (por ejemplo, no inició sesión).
  cancelada,
}
