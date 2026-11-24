import '../../negocios/data/lectura_json.dart';

/// Un reporte de soporte tal como lo devuelve la API (`ReporteDto`).
class Reporte {
  const Reporte({
    required this.id,
    required this.asunto,
    required this.estado,
    required this.creadaEn,
  });

  final String id;
  final String asunto;

  /// Hoy la API solo responde `abierto`.
  final String estado;
  final DateTime creadaEn;

  factory Reporte.fromJson(Map<String, dynamic> json) => Reporte(
    id: leerTexto(json, 'id'),
    asunto: leerTexto(json, 'asunto'),
    estado: leerTexto(json, 'estado'),
    creadaEn: DateTime.parse(leerTexto(json, 'creadaEn')),
  );
}
