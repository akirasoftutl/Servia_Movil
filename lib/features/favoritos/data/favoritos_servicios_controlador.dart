import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/data/auth_service.dart';
import '../mensajes.dart';
import 'favoritos_controlador.dart';
import 'favoritos_service.dart';
import 'servicio_favorito.dart';

/// Favoritos de servicios de la cuenta con sesión, compartidos por el corazón
/// del detalle del servicio y la pestaña «Servicios» de «Mis favoritos»
/// (HU-C84, T18). Igual que los de negocios ([FavoritosControlador]): agregar
/// y quitar son optimistas y se revierten si la API falla, y los datos son de
/// un solo `uid`: al cerrar sesión ([limpiar]) o entrar con otra cuenta se
/// descartan (RN-46).
class FavoritosServiciosControlador extends ChangeNotifier {
  FavoritosServiciosControlador({FavoritosService? service, AuthService? auth})
    : _service = service ?? FavoritosService(),
      _auth = auth ?? AuthService();

  /// El de la app. Las pruebas crean el suyo.
  static final FavoritosServiciosControlador instancia =
      FavoritosServiciosControlador();

  final FavoritosService _service;
  final AuthService _auth;

  final List<ServicioFavorito> _items = [];
  final Set<String> _guardando = {};
  EstadoFavoritos _estado = EstadoFavoritos.inicial;
  Object? _error;
  String? _uid;

  /// Cambia al limpiar o cambiar de cuenta: descarta respuestas atrasadas.
  int _generacion = 0;

  EstadoFavoritos get estado => _estado;
  Object? get error => _error;

  /// Del más reciente al más antiguo.
  List<ServicioFavorito> get items => List.unmodifiable(_items);

  bool esFavorito(String negocioId, String servicioId) =>
      _items.any((s) => s.clave == '$negocioId/$servicioId');
  bool estaGuardando(String negocioId, String servicioId) =>
      _guardando.contains('$negocioId/$servicioId');

  bool get haySesion {
    try {
      return _auth.usuarioActual != null;
    } catch (_) {
      return false;
    }
  }

  /// Consulta la lista de la cuenta actual. No lanza: deja el resultado en
  /// [estado] y [error]. Si ya había datos de la misma cuenta se conservan
  /// mientras llega la respuesta.
  Future<void> cargar() async {
    final usuario = haySesion ? _auth.usuarioActual : null;
    if (usuario == null) {
      limpiar();
      return;
    }
    if (_uid != usuario.uid) _reiniciar(usuario.uid);
    final generacion = _generacion;
    final conDatos = _estado == EstadoFavoritos.listo;
    if (!conDatos) {
      _estado = EstadoFavoritos.cargando;
      _error = null;
      notifyListeners();
    }
    try {
      final token = await _token(usuario.getIdToken);
      final lista = await _service.listarServicios(token);
      if (generacion != _generacion) return;
      // Un cambio en curso ya mostró el resultado esperado: no se pisa.
      if (_guardando.isNotEmpty) return;
      _items
        ..clear()
        ..addAll(lista);
      _estado = EstadoFavoritos.listo;
      _error = null;
    } catch (error) {
      if (generacion != _generacion) return;
      if (conDatos) return;
      _estado = EstadoFavoritos.error;
      _error = error;
    }
    notifyListeners();
  }

  /// Agrega [servicio] si no es favorito y lo quita si lo es. Lanza el error
  /// de la API (404, 409...) después de revertir el cambio.
  Future<void> alternar(ServicioFavorito servicio) async {
    final clave = servicio.clave;
    final usuario = haySesion ? _auth.usuarioActual : null;
    if (usuario == null) {
      throw const ApiException(401, MensajesFavoritos.sesionVencida);
    }
    if (_guardando.contains(clave)) return;
    final generacion = _generacion;
    final eraFavorito = _items.any((s) => s.clave == clave);
    final posicion = eraFavorito
        ? _items.indexWhere((s) => s.clave == clave)
        : 0;
    _guardando.add(clave);
    if (eraFavorito) {
      _items.removeAt(posicion);
    } else {
      _items.insert(0, servicio);
    }
    notifyListeners();
    try {
      final token = await _token(usuario.getIdToken);
      if (eraFavorito) {
        await _service.quitarServicio(
          token,
          servicio.negocioId,
          servicio.servicioId,
        );
      } else {
        await _service.agregarServicio(
          token,
          servicio.negocioId,
          servicio.servicioId,
        );
      }
    } catch (error) {
      if (generacion != _generacion) return;
      if (eraFavorito) {
        if (!_items.any((s) => s.clave == clave)) {
          _items.insert(posicion.clamp(0, _items.length), servicio);
        }
      } else {
        _items.removeWhere((s) => s.clave == clave);
      }
      _guardando.remove(clave);
      notifyListeners();
      rethrow;
    }
    if (generacion != _generacion) return;
    _guardando.remove(clave);
    notifyListeners();
  }

  /// Descarta todo (cerrar sesión o no haber sesión).
  void limpiar() {
    if (_uid == null && _items.isEmpty && _estado == EstadoFavoritos.inicial) {
      return;
    }
    _reiniciar(null);
    notifyListeners();
  }

  void _reiniciar(String? uid) {
    _generacion++;
    _uid = uid;
    _items.clear();
    _guardando.clear();
    _estado = EstadoFavoritos.inicial;
    _error = null;
  }

  Future<String> _token(Future<String?> Function([bool]) obtener) async {
    final token = await obtener();
    if (token == null) {
      throw const ApiException(401, MensajesFavoritos.sesionVencida);
    }
    return token;
  }
}
