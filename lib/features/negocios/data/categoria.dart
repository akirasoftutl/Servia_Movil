import 'lectura_json.dart';

class Categoria {
  final String id;
  final String nombre;
  final int orden;
  final bool activo;

  const Categoria({
    required this.id,
    required this.nombre,
    required this.orden,
    required this.activo,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
    id: leerTexto(json, 'id'),
    nombre: leerTexto(json, 'nombre'),
    orden: leerEntero(json, 'orden'),
    activo: leerBooleano(json, 'activo'),
  );
}
