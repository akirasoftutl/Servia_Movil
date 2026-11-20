/// Foto pública de un negocio, tal como llega en `GET /negocios/{id}`.
class FotoNegocio {
  const FotoNegocio({required this.id, required this.url});

  final String id;
  final String url;
}

/// Portada y galería del perfil público.
///
/// Un perfil de API anterior no trae `fotos`: se lee como sin portada y con
/// galería vacía. Un valor malformado se ignora para no romper el perfil.
class FotosNegocio {
  const FotosNegocio({this.portada, this.galeria = const []});

  static const vacias = FotosNegocio();

  final FotoNegocio? portada;
  final List<FotoNegocio> galeria;

  factory FotosNegocio.fromJson(Object? valor) {
    if (valor is! Map) return const FotosNegocio();
    return FotosNegocio(
      portada: _foto(valor['portada']),
      galeria: _galeria(valor['galeria']),
    );
  }

  static FotoNegocio? _foto(Object? valor) {
    if (valor is! Map) return null;
    final url = valor['url'];
    if (url is! String || url.isEmpty) return null;
    final id = valor['id'];
    return FotoNegocio(id: id is String ? id : url, url: url);
  }

  static List<FotoNegocio> _galeria(Object? valor) {
    if (valor is! List) return const [];
    return List.unmodifiable(valor.map(_foto).whereType<FotoNegocio>());
  }
}
