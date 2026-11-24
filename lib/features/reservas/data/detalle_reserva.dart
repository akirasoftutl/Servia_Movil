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
    required this.negocioId,
    required this.servicioId,
    this.reprogramable = false,
    this.reprogramableHasta,
    this.motivoNoReprogramable,
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

  /// Ids de la reserva guardada: sirven para elegir otro horario o servicio.
  final String negocioId;
  final String servicioId;

  /// Reprogramación (T18, T19, HU-C74): la decide la API, la app no la calcula.
  final bool reprogramable;

  /// Último instante en que se puede reprogramar (UTC); null si ya no se puede.
  final DateTime? reprogramableHasta;

  /// Texto en español de la API cuando no se puede reprogramar.
  final String? motivoNoReprogramable;

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
      negocioId: leerTexto(negocio, 'id'),
      servicioId: leerTexto(leerObjeto(json['servicio']), 'id'),
      // Sin el campo (API anterior) no se ofrece cambiar nada.
      reprogramable: json['reprogramable'] == true,
      reprogramableHasta: _fechaOpcional(json, 'reprogramableHasta'),
      motivoNoReprogramable: leerTextoOpcional(json, 'motivoNoReprogramable'),
    );
  }
}

DateTime? _fechaOpcional(Map<String, dynamic> json, String campo) {
  if (json[campo] == null) return null;
  final fecha = DateTime.tryParse(leerTexto(json, campo));
  if (fecha == null) throw FormatException('Campo inválido: $campo.');
  return fecha;
}
