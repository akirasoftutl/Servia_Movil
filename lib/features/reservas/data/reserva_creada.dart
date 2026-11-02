import '../../negocios/data/lectura_json.dart';

/// Respuesta de `POST /reservas` (MVP-18). Toda reserva nueva es Pendiente (RN-55).
class ReservaCreada {
  const ReservaCreada({
    required this.id,
    required this.folio,
    required this.estado,
    required this.inicio,
    required this.fin,
    required this.precio,
    required this.duracionMin,
    required this.venceEn,
  });

  final String id;
  final String folio;
  final String estado;
  final DateTime inicio;
  final DateTime fin;
  final num precio;
  final int duracionMin;
  final DateTime venceEn;

  factory ReservaCreada.fromJson(Map<String, dynamic> json) {
    final precio = json['precio'];
    if (precio is! num) throw const FormatException('Precio inválido.');
    final folio = leerTexto(json, 'folio');
    if (folio.isEmpty) throw const FormatException('Folio inválido.');
    return ReservaCreada(
      id: leerTexto(json, 'id'),
      folio: folio,
      estado: leerTexto(json, 'estado'),
      inicio: _leerFecha(json, 'inicio'),
      fin: _leerFecha(json, 'fin'),
      precio: precio,
      duracionMin: leerEntero(json, 'duracionMin'),
      venceEn: _leerFecha(json, 'venceEn'),
    );
  }
}

DateTime _leerFecha(Map<String, dynamic> json, String campo) {
  final valor = DateTime.tryParse(leerTexto(json, campo));
  if (valor == null) throw FormatException('Campo inválido: $campo.');
  return valor;
}
