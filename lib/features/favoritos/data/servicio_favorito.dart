import '../../negocios/data/lectura_json.dart';
import '../../negocios/data/negocios_service.dart';

/// Servicio guardado como favorito, tal como lo devuelve
/// `GET /favoritos/servicios` (Servia_BE#122, HU-C84). No trae descripción:
/// el detalle completo se consulta al abrirlo.
class ServicioFavorito {
  const ServicioFavorito({
    required this.servicioId,
    required this.nombre,
    required this.precio,
    required this.duracionMin,
    required this.negocioId,
    required this.negocioNombre,
    required this.aceptaReservas,
  });

  factory ServicioFavorito.fromJson(Map<String, dynamic> json) {
    final precio = json['precio'];
    if (precio is! num) throw const FormatException('Precio inválido.');
    final servicioId = leerTexto(json, 'servicioId');
    final negocioId = leerTexto(json, 'negocioId');
    if (!esIdValido(servicioId) || !esIdValido(negocioId)) {
      throw const FormatException('Id inválido.');
    }
    return ServicioFavorito(
      servicioId: servicioId,
      nombre: leerTexto(json, 'nombre'),
      precio: precio,
      duracionMin: leerEntero(json, 'duracionMin'),
      negocioId: negocioId,
      negocioNombre: leerTexto(json, 'negocioNombre'),
      aceptaReservas: leerBooleano(json, 'aceptaReservas'),
    );
  }

  final String servicioId;
  final String nombre;
  final num precio;
  final int duracionMin;
  final String negocioId;
  final String negocioNombre;
  final bool aceptaReservas;

  /// Un `servicioId` solo es único dentro de su negocio.
  String get clave => '$negocioId/$servicioId';
}
