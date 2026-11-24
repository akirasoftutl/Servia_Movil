import 'fotos_negocio.dart';
import 'lectura_json.dart';

class Servicio {
  final String id;
  final String nombre;
  final String? descripcion;
  final num precio;
  final int duracionMin;

  /// Imágenes en orden de subida (la primera es la de arriba; máximo 3, T19).
  /// Una respuesta anterior sin `imagenes` o malformada se lee como `[]`.
  final List<FotoNegocio> imagenes;

  const Servicio({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.duracionMin,
    this.imagenes = const [],
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
      imagenes: FotosNegocio.lista(json['imagenes']),
    );
  }
}
