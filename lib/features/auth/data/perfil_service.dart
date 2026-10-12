import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'perfil.dart';

class PerfilService {
  final ApiClient _api;

  PerfilService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<Perfil> obtenerYo(String token) async {
    final respuesta = await _api.get('/auth/yo', token: token);

    if (respuesta.statusCode == 200) {
      final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
      return Perfil.fromJson(datos);
    }

    String mensaje;
    if (respuesta.statusCode == 403) {
      mensaje = 'Tu cuenta está desactivada.';
    } else if (respuesta.statusCode >= 500) {
      mensaje = 'La API no está disponible. Intenta más tarde.';
    } else {
      mensaje = 'No se pudo verificar la sesión.';
    }
    throw ApiException(respuesta.statusCode, mensaje);
  }
}