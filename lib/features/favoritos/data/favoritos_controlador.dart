import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/data/auth_service.dart';
import '../../negocios/data/negocio_resumen.dart';
import '../mensajes.dart';
import 'favoritos_service.dart';

enum EstadoFavoritos { inicial, cargando, listo, error }

/// Favoritos de negocios de la cuenta con sesión, compartidos por el corazón
/// del perfil, el de cada tarjeta y «Mis favoritos» (HU-C81 a HU-C83).
///
/// Agregar y quitar son optimistas: el cambio se ve al instante y se revierte
/// si la API falla. Los favoritos pertenecen a un solo `uid`: al cerrar sesión
/// ([limpiar]) o entrar con otra cuenta se descartan (RN-46).
class FavoritosControlador extends ChangeNotifier {
  FavoritosControlador({FavoritosService? service, AuthService? auth})
    : _service = service ?? FavoritosService(),
      _auth = auth ?? AuthService();

  /// El de la app. Las pruebas crean el suyo.
  static final FavoritosControlador instancia = FavoritosControlador();

  final FavoritosService _service;
  final AuthService _auth;

  final List<NegocioResumen> _items = [];
  final Set<String> _guardando = {};
  EstadoFavoritos _estado = EstadoFavoritos.inicial;
  Object? _error;
  String? _uid;

  /// Cambia al limpiar o cambiar de cuenta: descarta respuestas atrasadas.
  int _generacion = 0;

  EstadoFavoritos get estado => _estado;
  Object? get error => _error;

  /// Del más reciente al más antiguo.
  List<NegocioResumen> get items => List.unmodifiable(_items);

  bool esFavorito(String negocioId) => _items.any((n) => n.id == negocioId);
  bool estaGuardando(String negocioId) => _guardando.contains(negocioId);

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
      final lista = await _service.listar(await _token(usuario.getIdToken));
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

  /// Agrega [negocio] si no es favorito y lo quita si lo es. Lanza el error
  /// de la API (404, 409...) después de revertir el cambio.
  Future<void> alternar(NegocioResumen negocio) async {
    final id = negocio.id;
    final usuario = haySesion ? _auth.usuarioActual : null;
    if (usuario == null) {
      throw const ApiException(401, MensajesFavoritos.sesionVencida);
    }
    if (_guardando.contains(id)) return;
    final generacion = _generacion;
    final eraFavorito = esFavorito(id);
    final posicion = eraFavorito ? _items.indexWhere((n) => n.id == id) : 0;
    _guardando.add(id);
    if (eraFavorito) {
      _items.removeAt(posicion);
    } else {
      _items.insert(0, negocio);
    }
    notifyListeners();
    try {
      final token = await _token(usuario.getIdToken);
      if (eraFavorito) {
        await _service.quitar(token, id);
      } else {
        await _service.agregar(token, id);
      }
    } catch (error) {
      if (generacion != _generacion) return;
      if (eraFavorito) {
        if (!esFavorito(id)) {
          _items.insert(posicion.clamp(0, _items.length), negocio);
        }
      } else {
        _items.removeWhere((n) => n.id == id);
      }
      _guardando.remove(id);
      notifyListeners();
      rethrow;
    }
    if (generacion != _generacion) return;
    _guardando.remove(id);
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
