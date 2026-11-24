import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../negocios/data/lectura_json.dart';
import '../../negocios/data/negocio_resumen.dart';
import '../../negocios/data/negocios_service.dart';
import '../mensajes.dart';
import 'servicio_favorito.dart';

/// Contrato de la API de favoritos de negocios (Servia_BE#111, T17).
///
/// Los tres endpoints piden el token de un cliente. La app nunca escribe en
/// Firestore: solo la API guarda los favoritos de cada cuenta.
class FavoritosService {
  FavoritosService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// `GET /favoritos/negocios` → 200 `{ items }`, del más reciente al más
  /// antiguo (hasta 100). Ya no trae los negocios no visibles.
  Future<List<NegocioResumen>> listar(String token) async {
    final respuesta = await _api.get('/favoritos/negocios', token: token);
    if (respuesta.statusCode != 200) {
      throw _error(respuesta.statusCode, respuesta.body);
    }
    final items = leerObjeto(jsonDecode(respuesta.body))['items'];
    if (items is! List) {
      throw const FormatException('Lista de favoritos inválida.');
    }
    return List.unmodifiable(
      items.map((item) => NegocioResumen.fromJson(leerObjeto(item))),
    );
  }

  /// `PUT /favoritos/negocios/{id}` sin cuerpo → 204 (idempotente).
  /// 404: el negocio no existe o no está disponible. 409: tope de 100.
  Future<void> agregar(String token, String negocioId) async {
    final respuesta = await _api.put(_ruta(negocioId), token: token);
    if (respuesta.statusCode != 204) {
      throw _error(respuesta.statusCode, respuesta.body);
    }
  }

  /// `DELETE /favoritos/negocios/{id}` → 204 aunque no fuera favorito.
  Future<void> quitar(String token, String negocioId) async {
    final respuesta = await _api.delete(_ruta(negocioId), token: token);
    if (respuesta.statusCode != 204) {
      throw _error(respuesta.statusCode, respuesta.body);
    }
  }

  /// `GET /favoritos/servicios` → 200 `{ items }`, del más reciente al más
  /// antiguo (hasta 100, sin `siguiente`). Ya no trae los servicios inactivos
  /// ni los de negocios no visibles (Servia_BE#122, HU-C84).
  Future<List<ServicioFavorito>> listarServicios(String token) async {
    final respuesta = await _api.get('/favoritos/servicios', token: token);
    if (respuesta.statusCode != 200) {
      throw _error(respuesta.statusCode, respuesta.body);
    }
    final items = leerObjeto(jsonDecode(respuesta.body))['items'];
    if (items is! List) {
      throw const FormatException('Lista de favoritos inválida.');
    }
    return List.unmodifiable(
      items.map((item) => ServicioFavorito.fromJson(leerObjeto(item))),
    );
  }

  /// `PUT /favoritos/servicios/{negocioId}/{servicioId}` sin cuerpo → 204
  /// (idempotente). 404: el servicio no existe o no está disponible. 409:
  /// tope de 100 servicios.
  Future<void> agregarServicio(
    String token,
    String negocioId,
    String servicioId,
  ) async {
    final respuesta = await _api.put(
      _rutaServicio(negocioId, servicioId),
      token: token,
    );
    if (respuesta.statusCode != 204) {
      throw _error(respuesta.statusCode, respuesta.body);
    }
  }

  /// `DELETE /favoritos/servicios/{negocioId}/{servicioId}` → 204 aunque no
  /// fuera favorito.
  Future<void> quitarServicio(
    String token,
    String negocioId,
    String servicioId,
  ) async {
    final respuesta = await _api.delete(
      _rutaServicio(negocioId, servicioId),
      token: token,
    );
    if (respuesta.statusCode != 204) {
      throw _error(respuesta.statusCode, respuesta.body);
    }
  }

  String _rutaServicio(String negocioId, String servicioId) {
    if (!esIdValido(negocioId) || !esIdValido(servicioId)) {
      throw ApiException(404, MensajesFavoritos.errorGuardar);
    }
    return '/favoritos/servicios/${Uri.encodeComponent(negocioId)}'
        '/${Uri.encodeComponent(servicioId)}';
  }

  String _ruta(String negocioId) {
    if (!esIdValido(negocioId)) {
      throw ApiException(404, MensajesFavoritos.errorGuardar);
    }
    return '/favoritos/negocios/${Uri.encodeComponent(negocioId)}';
  }

  /// Error con el mensaje del cuerpo estándar de Nest
  /// `{ statusCode, message, error }` cuando lo trae.
  ApiException _error(int codigo, String cuerpo) {
    String? mensaje;
    try {
      final datos = jsonDecode(cuerpo);
      final texto = datos is Map ? datos['message'] : null;
      if (texto is String) mensaje = texto;
      if (texto is List) mensaje = texto.whereType<String>().join(' ');
    } catch (_) {
      // Un cuerpo que no es JSON se trata como sin mensaje.
    }
    return ApiException(codigo, mensaje ?? MensajesFavoritos.errorGuardar);
  }
}
