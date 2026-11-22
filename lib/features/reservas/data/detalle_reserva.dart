import '../../negocios/data/lectura_json.dart';
import 'reserva_resumen.dart';

/// Detalle propio entregado por la API (MVP-20, RN-45).
/// Conserva la copia del servicio y los permisos calculados por el backend.
class DetalleReserva extends ReservaResumen {
  const DetalleReserva({
    required super.id,
    required super.folio,
    required super.estado,
    required super.inicio,
    required super.fin,
    required super.servicio,
    required super.negocio,
    required this.precio,
    required this.duracionMin,
    required this.direccionTexto,
    required this.telefono,
    required this.venceEn,
    required this.observaciones,
    required this.motivo,
    required this.cancelable,
    required this.cancelableHasta,
  });

  final num? precio;
  final int? duracionMin;
  final String direccionTexto;
  final String telefono;
  final DateTime? venceEn;
  final String? observaciones;
  final String? motivo;
  final bool cancelable;
  final DateTime? cancelableHasta;

  factory DetalleReserva.fromJson(Map<String, dynamic> json) {
    final resumen = ReservaResumen.fromJson(json);
    final servicio = leerObjeto(json['servicio']);
    final negocio = leerObjeto(json['negocio']);
    final precio = servicio['precio'];
    if (precio != null && precio is! num) {
      throw const FormatException('Campo inválido: precio.');
    }
    return DetalleReserva(
      id: resumen.id,
      folio: resumen.folio,
      estado: resumen.estado,
      inicio: resumen.inicio,
      fin: resumen.fin,
      servicio: resumen.servicio,
      negocio: resumen.negocio,
      precio: precio as num?,
      duracionMin: servicio['duracionMin'] == null
          ? null
          : leerEntero(servicio, 'duracionMin'),
      direccionTexto: leerTexto(negocio, 'direccionTexto'),
      telefono: leerTexto(negocio, 'telefono'),
      venceEn: _fechaOpcional(json, 'venceEn'),
      observaciones: leerTextoOpcional(json, 'observaciones'),
      motivo: leerTextoOpcional(json, 'motivo'),
      cancelable: leerBooleano(json, 'cancelable'),
      cancelableHasta: _fechaOpcional(json, 'cancelableHasta'),
    );
  }
}

DateTime? _fechaOpcional(Map<String, dynamic> json, String campo) {
  if (json[campo] == null) return null;
  final fecha = DateTime.tryParse(leerTexto(json, campo));
  if (fecha == null) throw FormatException('Campo inválido: $campo.');
  return fecha;
}
