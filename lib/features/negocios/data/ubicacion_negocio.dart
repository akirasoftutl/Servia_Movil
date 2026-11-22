import 'lectura_json.dart';

class UbicacionNegocio {
  const UbicacionNegocio({required this.lat, required this.lng});
  final double lat;
  final double lng;

  /// Un perfil anterior o con coordenadas malformadas sigue siendo consultable.
  static UbicacionNegocio? leer(Object? valor) {
    try {
      final objeto = leerObjeto(valor);
      final lat = leerNumero(objeto, 'lat');
      final lng = leerNumero(objeto, 'lng');
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
      return UbicacionNegocio(lat: lat, lng: lng);
    } on FormatException {
      return null;
    }
  }
}
