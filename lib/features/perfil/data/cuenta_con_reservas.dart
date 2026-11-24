import 'dart:convert';

import '../../../core/network/api_exception.dart';

/// Una reserva que impide eliminar la cuenta (Pendiente o Confirmada).
class ReservaPorAtender {
  const ReservaPorAtender({
    required this.id,
    required this.folio,
    required this.estado,
    required this.inicio,
  });

  final String id;
  final String folio;

  /// `pendiente` o `confirmada`.
  final String estado;

  /// Instante de la cita en UTC; se muestra en la zona de México.
  final DateTime inicio;

  static ReservaPorAtender? deJson(Object? valor) {
    if (valor is! Map) return null;
    final id = valor['id'];
    final folio = valor['folio'];
    final estado = valor['estado'];
    final inicio = valor['inicio'];
    if (id is! String || folio is! String || estado is! String) return null;
    if (inicio is! String) return null;
    final fecha = DateTime.tryParse(inicio);
    if (fecha == null) return null;
    return ReservaPorAtender(
      id: id,
      folio: folio,
      estado: estado,
      inicio: fecha.toUtc(),
    );
  }
}

/// `409` de `DELETE /usuarios/yo` (Servia_BE#116): la cuenta tiene reservas
/// por atender. Trae hasta 10, la más cercana primero; [total] es el número
/// real y el [mensaje] ya viene en español con los folios.
class CuentaConReservasException extends ApiException {
  CuentaConReservasException({
    required String mensaje,
    required this.total,
    required this.reservas,
  }) : super(409, mensaje);

  final int total;
  final List<ReservaPorAtender> reservas;

  /// Lee el cuerpo del 409; lo malformado se ignora para no perder el aviso.
  factory CuentaConReservasException.deCuerpo(
    String cuerpo, {
    required String porDefecto,
  }) {
    var mensaje = porDefecto;
    var total = 0;
    final reservas = <ReservaPorAtender>[];
    try {
      final datos = jsonDecode(cuerpo);
      if (datos is Map) {
        final texto = datos['message'];
        if (texto is String && texto.isNotEmpty) mensaje = texto;
        final cantidad = datos['total'];
        if (cantidad is int) total = cantidad;
        final lista = datos['reservas'];
        if (lista is List) {
          for (final item in lista) {
            final reserva = ReservaPorAtender.deJson(item);
            if (reserva != null) reservas.add(reserva);
          }
        }
      }
    } catch (_) {}
    return CuentaConReservasException(
      mensaje: mensaje,
      total: total,
      reservas: reservas,
    );
  }
}
