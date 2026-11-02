import 'lectura_json.dart';

class Servicio {
  final String id;
  final String nombre;
  final String? descripcion;
  final num precio;
  final int duracionMin;

  const Servicio({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.duracionMin,
  });

  factory Servicio.fromJson(Map<String, dynamic> json) {
    final precio = json['precio'];
    if (precio is! num) throw const FormatException('Precio inválido.');
    return Servicio(
      id: leerTexto(json, 'id'),
      nombre: leerTexto(json, 'nombre'),
      descripcion: leerTextoOpcional(json, 'descripcion'),
      precio: precio,
      duracionMin: leerEntero(json, 'duracionMin'),
    );
  }
}
