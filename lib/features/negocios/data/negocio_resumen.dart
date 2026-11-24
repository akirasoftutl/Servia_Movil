import 'fotos_negocio.dart';
import 'lectura_json.dart';
import 'negocios_service.dart';

class NegocioResumen {
  final String id;
  final String nombre;

  /// La API declara `categoriaId` como `string | null`.
  final String? categoriaId;
  final bool aceptaReservas;

  /// URL de la portada incluida en el listado de negocios.
  final String? imagenUrl;

  const NegocioResumen({
    required this.id,
    required this.nombre,
    this.categoriaId,
    required this.aceptaReservas,
    this.imagenUrl,
  });

  factory NegocioResumen.fromJson(Map<String, dynamic> json) {
    final id = leerTexto(json, 'id');
    if (!esIdValido(id)) throw const FormatException('Id inválido.');
    return NegocioResumen(
      id: id,
      nombre: leerTexto(json, 'nombre'),
      categoriaId: _leerCategoriaId(json),
      aceptaReservas: leerBooleano(json, 'aceptaReservas'),
      imagenUrl: _leerImagenUrl(json),
    );
  }

  static String? _leerCategoriaId(Map<String, dynamic> json) {
    if (json['categoriaId'] == null) return null;
    return leerTexto(json, 'categoriaId');
  }

  static String? _leerImagenUrl(Map<String, dynamic> json) {
    final portada = FotosNegocio.fromJson(json['fotos']).portada;
    if (portada != null && portada.url.isNotEmpty) return portada.url;

    for (final campo in ['imagenUrl', 'fotoPortada', 'portada']) {
      final valor = json[campo];
      if (valor is String && valor.isNotEmpty) return valor;
      final foto = FotosNegocio.fromJson({'portada': valor}).portada;
      if (foto != null && foto.url.isNotEmpty) return foto.url;
    }
    return null;
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
