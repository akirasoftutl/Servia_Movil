import 'fotos_negocio.dart';
import 'lectura_json.dart';

/// Categoría del catálogo de servicios (`GET /categorias-servicio`) que el
/// negocio eligió para un servicio. La API la entrega como `{id, nombre}`.
class CategoriaServicio {
  final String id;
  final String nombre;

  const CategoriaServicio({required this.id, required this.nombre});

  /// Tolerante: un valor ausente o malformado es `null` (el servicio se ve
  /// como antes de las categorías).
  static CategoriaServicio? leer(Object? valor) {
    if (valor is! Map<String, dynamic>) return null;
    final id = valor['id'];
    final nombre = valor['nombre'];
    if (id is! String || id.isEmpty) return null;
    if (nombre is! String || nombre.trim().isEmpty) return null;
    return CategoriaServicio(id: id, nombre: nombre);
  }
}

class Servicio {
  final String id;
  final String nombre;
  final String? descripcion;
  final num precio;
  final int duracionMin;

  /// Imágenes en orden de subida (la primera es la de arriba; máximo 3, T19).
  /// Una respuesta anterior sin `imagenes` o malformada se lee como `[]`.
  final List<FotoNegocio> imagenes;

  /// Categoría del catálogo (T18); `null` si no tiene o es un servicio viejo.
  final CategoriaServicio? categoriaServicio;

  /// Categoría escrita por el negocio (hasta 40 caracteres, T19). A lo sumo
  /// una de las dos categorías tiene valor; esta no genera chip de filtro.
  final String? categoriaPersonalizada;

  /// Lo que se muestra al cliente: la de catálogo o, si no, la personalizada.
  String? get categoria => categoriaServicio?.nombre ?? categoriaPersonalizada;

  const Servicio({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.duracionMin,
    this.imagenes = const [],
    this.categoriaServicio,
    this.categoriaPersonalizada,
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
      categoriaServicio: CategoriaServicio.leer(json['categoriaServicio']),
      categoriaPersonalizada: _textoOpcional(json['categoriaPersonalizada']),
    );
  }
}

String? _textoOpcional(Object? valor) {
  if (valor is! String || valor.trim().isEmpty) return null;
  return valor;
}
