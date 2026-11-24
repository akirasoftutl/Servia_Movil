import '../../negocios/data/lectura_json.dart';
import 'reserva_creada.dart';

/// Respuesta de `PATCH /reservas/mias/{id}/reprogramar` (T18, HU-C71 a C73):
/// los mismos datos que una reserva nueva (siempre Pendiente) más el instante
/// en que se reprogramó.
class ReservaReprogramada {
  const ReservaReprogramada({
    required this.reserva,
    required this.reprogramadaEn,
  });

  final ReservaCreada reserva;
  final DateTime reprogramadaEn;

  factory ReservaReprogramada.fromJson(Map<String, dynamic> json) {
    final fecha = DateTime.tryParse(leerTexto(json, 'reprogramadaEn'));
    if (fecha == null) {
      throw const FormatException('Campo inválido: reprogramadaEn.');
    }
    return ReservaReprogramada(
      reserva: ReservaCreada.fromJson(json),
      reprogramadaEn: fecha,
    );
  }
}
