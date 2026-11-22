import 'package:geolocator/geolocator.dart';

typedef PosicionCliente = ({double lat, double lng});
typedef ProveedorUbicacionCliente = Future<PosicionCliente?> Function();

/// Solo una lectura aproximada; sin seguimiento, persistencia ni registros.
class UbicacionCliente {
  UbicacionCliente({GeolocatorPlatform? plataforma})
    : _plataforma = plataforma ?? GeolocatorPlatform.instance;

  final GeolocatorPlatform _plataforma;

  Future<PosicionCliente?> obtener() async {
    try {
      if (!await _plataforma.isLocationServiceEnabled()) return null;
      var permiso = await _plataforma.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await _plataforma.requestPermission();
      }
      if (permiso != LocationPermission.whileInUse &&
          permiso != LocationPermission.always) {
        return null;
      }
      final posicion = await _plataforma.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return (lat: posicion.latitude, lng: posicion.longitude);
    } catch (_) {
      return null;
    }
  }
}
