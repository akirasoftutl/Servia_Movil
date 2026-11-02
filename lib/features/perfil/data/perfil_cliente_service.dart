import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../mensajes.dart';
import 'perfil_cliente.dart';

/// Lee y guarda el perfil del cliente con la API (`/usuarios/yo`, MVP-05).
/// La app nunca escribe directo en Firestore.
class PerfilClienteService {
  final ApiClient _api;

  PerfilClienteService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<PerfilCliente> obtener(String token) async {
    final respuesta = await _api.get('/usuarios/yo', token: token);
    return _leer(respuesta, 200);
  }

  /// Envía solo los campos que no son nulos (el PATCH es parcial y responde 400
  /// si el cuerpo viene vacío).
  Future<PerfilCliente> actualizar(
    String token, {
    String? nombre,
    String? telefono,
    String? correo,
  }) async {
    final cuerpo = <String, String>{
      'nombre': ?nombre,
      'telefono': ?telefono,
      'correo': ?correo,
    };
    final respuesta = await _api.patch(
      '/usuarios/yo',
      token: token,
      body: jsonEncode(cuerpo),
    );
    return _leer(respuesta, 200);
  }

  PerfilCliente _leer(http.Response respuesta, int esperado) {
    if (respuesta.statusCode == esperado) {
      final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
      return PerfilCliente.fromJson(datos);
    }
    final codigo = respuesta.statusCode;
    final String mensaje;
    if (codigo == 409) {
      mensaje = MensajesPerfil.correoEnUso;
    } else if (codigo == 400) {
      mensaje =
          _mensajeDeLaApi(respuesta.body) ?? MensajesPerfil.datosInvalidos;
    } else if (codigo == 401) {
      mensaje = MensajesPerfil.sesionInvalida;
    } else if (codigo == 403) {
      mensaje = MensajesPerfil.cuentaDesactivada;
    } else if (codigo == 404) {
      mensaje = MensajesPerfil.sinPerfil;
    } else if (codigo >= 500) {
      mensaje = MensajesPerfil.errorApi;
    } else {
      mensaje = MensajesPerfil.errorGeneral;
    }
    throw ApiException(codigo, mensaje);
  }

  String? _mensajeDeLaApi(String cuerpo) {
    try {
      final datos = jsonDecode(cuerpo);
      if (datos is Map) {
        final mensaje = datos['message'];
        if (mensaje is List && mensaje.isNotEmpty) return '${mensaje.first}';
        if (mensaje is String && mensaje.isNotEmpty) return mensaje;
      }
    } catch (_) {}
    return null;
  }
}
