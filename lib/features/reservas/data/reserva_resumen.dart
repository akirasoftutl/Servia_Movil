import '../../negocios/data/lectura_json.dart';

/// Reserva del cliente en «Mis reservas» (MVP-19).
///
/// `inicio` y `fin` son los instantes ISO 8601 que devuelve la API (UTC);
/// la conversión a America/Mexico_City se hace al mostrarlos.
class ReservaResumen {
  const ReservaResumen({
    required this.id,
    required this.folio,
    required this.estado,
    required this.inicio,
    required this.fin,
    required this.servicio,
    required this.negocio,
  });

  final String id;
  final String folio;

  /// Valor crudo de la API: `pendiente`, `confirmada`, `rechazada`, ...
  final String estado;
  final DateTime inicio;
  final DateTime fin;

  /// Nombres del servicio y del negocio, tal como vienen en la respuesta.
  final String servicio;
  final String negocio;

  factory ReservaResumen.fromJson(Map<String, dynamic> json) {
    return ReservaResumen(
      id: leerTexto(json, 'id'),
      folio: leerTexto(json, 'folio'),
      estado: leerTexto(json, 'estado'),
      inicio: _leerFecha(json, 'inicio'),
      fin: _leerFecha(json, 'fin'),
      servicio: leerTexto(leerObjeto(json['servicio']), 'nombre'),
      negocio: leerTexto(leerObjeto(json['negocio']), 'nombre'),
    );
  }
}

DateTime _leerFecha(Map<String, dynamic> json, String campo) {
  final valor = DateTime.tryParse(leerTexto(json, campo));
  if (valor == null) throw FormatException('Campo inválido: $campo.');
  return valor;
}

/// Respuesta paginada de `GET /reservas/mias`.
class PaginaReservas {
  const PaginaReservas({required this.items, required this.siguiente});

  final List<ReservaResumen> items;
  final String? siguiente;

  factory PaginaReservas.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final siguiente = json['siguiente'];
    if (items is! List ||
        !json.containsKey('siguiente') ||
        (siguiente != null && siguiente is! String)) {
      throw const FormatException('Página inválida.');
    }
    return PaginaReservas(
      items: List.unmodifiable(
        items.map((item) => ReservaResumen.fromJson(leerObjeto(item))),
      ),
      siguiente: siguiente as String?,
    );
  }
}
