import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../negocios/data/lectura_json.dart';
import '../mensajes.dart';
import 'aviso.dart';

/// Contrato de la API de avisos (MVP-28, historia 76).
///
/// La app solo habla con estos endpoints: nunca escribe en Firestore.
class NotificacionesService {
  NotificacionesService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// `POST /notificaciones/tokens` (204). Idempotente en la API.
  Future<void> registrarToken(String token, String tokenFcm) async {
    final respuesta = await _api.post(
      '/notificaciones/tokens',
      token: token,
      body: jsonEncode({'token': tokenFcm, 'plataforma': 'android'}),
    );
    if (!_esExito(respuesta.statusCode)) {
      throw ApiException(respuesta.statusCode, MensajesNotificaciones.errorCarga);
    }
  }

  /// `DELETE /notificaciones/tokens` (204), antes de cerrar la sesión.
  Future<void> desactivarToken(String token, String tokenFcm) async {
    final respuesta = await _api.delete(
      '/notificaciones/tokens',
      token: token,
      body: jsonEncode({'token': tokenFcm}),
    );
    if (!_esExito(respuesta.statusCode)) {
      throw ApiException(respuesta.statusCode, MensajesNotificaciones.errorCarga);
    }
  }

  /// `GET /notificaciones`, del más nuevo al más viejo, paginado por cursor.
  Future<PaginaAvisos> listar(String token, {String? cursor}) async {
    final query = <String, String>{
      'limite': '20',
      'cursor': ?cursor,
    };
    final uri = Uri(path: '/notificaciones', queryParameters: query);
    final respuesta = await _api.get('$uri', token: token);
    if (respuesta.statusCode != 200) {
      throw ApiException(
        respuesta.statusCode,
        MensajesNotificaciones.errorCarga,
      );
    }
    return PaginaAvisos.fromJson(
      leerObjeto(jsonDecode(respuesta.body)),
    );
  }

  /// `PATCH /notificaciones/:id/leida`.
  Future<void> marcarLeida(String token, String id) async {
    final respuesta = await _api.patch(
      '/notificaciones/${Uri.encodeComponent(id)}/leida',
      token: token,
    );
    if (!_esExito(respuesta.statusCode)) {
      throw ApiException(respuesta.statusCode, MensajesNotificaciones.errorCarga);
    }
  }

  bool _esExito(int codigo) => codigo >= 200 && codigo < 300;
}
