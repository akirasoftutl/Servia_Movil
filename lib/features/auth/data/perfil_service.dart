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

  /// Crea el perfil de cliente de una cuenta que acaba de entrar con Google.
  /// El backend toma nombre y correo del ID token verificado, así que aquí no
  /// se envían datos del usuario que puedan falsificarse.
  Future<void> asegurarPerfilGoogle(String token) async {
    final respuesta = await _api.post('/auth/google', token: token);

    if (respuesta.statusCode == 200 || respuesta.statusCode == 201) return;

    String mensaje;
    if (respuesta.statusCode == 403) {
      mensaje = 'Esta app es para clientes.';
    } else if (respuesta.statusCode >= 500) {
      mensaje = 'La API no está disponible. Intenta más tarde.';
    } else {
      mensaje = 'No se pudo preparar tu cuenta de Google.';
    }
    throw ApiException(respuesta.statusCode, mensaje);
  }
}
