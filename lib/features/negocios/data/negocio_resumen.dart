import 'lectura_json.dart';
import 'negocios_service.dart';

class NegocioResumen {
  final String id;
  final String nombre;
  final String categoriaId;
  final bool aceptaReservas;

  const NegocioResumen({
    required this.id,
    required this.nombre,
    required this.categoriaId,
    required this.aceptaReservas,
  });

  factory NegocioResumen.fromJson(Map<String, dynamic> json) {
    final id = leerTexto(json, 'id');
    if (!esIdValido(id)) throw const FormatException('Id inválido.');
    return NegocioResumen(
      id: id,
      nombre: leerTexto(json, 'nombre'),
      categoriaId: leerTexto(json, 'categoriaId'),
      aceptaReservas: leerBooleano(json, 'aceptaReservas'),
    );
  }
}

class PaginaNegocios {
  final List<NegocioResumen> items;
  final String? siguiente;

  const PaginaNegocios({required this.items, required this.siguiente});

  factory PaginaNegocios.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final siguiente = json['siguiente'];
    if (items is! List ||
        !json.containsKey('siguiente') ||
        (siguiente != null && siguiente is! String)) {
      throw const FormatException('Página inválida.');
    }
    return PaginaNegocios(
      items: List.unmodifiable(
        items.map((item) => NegocioResumen.fromJson(leerObjeto(item))),
      ),
      siguiente: siguiente as String?,
    );
  }
}
