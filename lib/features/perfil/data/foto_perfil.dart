/// Foto de perfil del cliente, tal como la entrega la API: `{ id, url }`
/// (`GET`/`PATCH /usuarios/yo` y `POST /usuarios/yo/foto`, Servia_BE#115).
class FotoPerfil {
  const FotoPerfil({required this.id, required this.url});

  final String id;
  final String url;

  /// Un valor ausente o malformado se lee como sin foto, para no romper
  /// «Mi perfil» con una API anterior.
  static FotoPerfil? deJson(Object? valor) {
    if (valor is! Map) return null;
    final id = valor['id'];
    final url = valor['url'];
    if (id is! String || url is! String || url.isEmpty) return null;
    return FotoPerfil(id: id, url: url);
  }
}
