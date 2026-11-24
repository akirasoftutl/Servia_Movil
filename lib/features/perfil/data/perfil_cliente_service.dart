import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../mensajes.dart';
import 'foto_perfil.dart';
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

  /// Sube la foto de perfil (`POST /usuarios/yo/foto`, multipart con el campo
  /// `archivo`); si ya había una, la API la reemplaza.
  Future<FotoPerfil> subirFoto(
    String token,
    Uint8List bytes,
    String nombre,
  ) async {
    final respuesta = await _api.postArchivo(
      '/usuarios/yo/foto',
      token: token,
      campo: 'archivo',
      bytes: bytes,
      nombre: nombre,
    );
    if (respuesta.statusCode == 201) {
      final foto = FotoPerfil.deJson(jsonDecode(respuesta.body));
      if (foto != null) return foto;
      throw ApiException(respuesta.statusCode, MensajesPerfil.errorGeneral);
    }
    throw _errorDeFoto(respuesta, MensajesPerfil.fotoNoGuardada);
  }

  /// Quita la foto (`DELETE /usuarios/yo/foto`, 204; no falla si no había).
  Future<void> quitarFoto(String token) async {
    final respuesta = await _api.delete('/usuarios/yo/foto', token: token);
    if (respuesta.statusCode == 204) return;
    throw _errorDeFoto(respuesta, MensajesPerfil.fotoNoQuitada);
  }

  /// 400, 413 y 503 traen un mensaje en español de la API; se conserva.
  ApiException _errorDeFoto(http.Response respuesta, String porDefecto503) {
    final codigo = respuesta.statusCode;
    final deLaApi = _mensajeDeLaApi(respuesta.body);
    final String mensaje;
    if (codigo == 400) {
      mensaje = deLaApi ?? MensajesPerfil.fotoFormato;
    } else if (codigo == 413) {
      mensaje = deLaApi ?? MensajesPerfil.fotoGrande;
    } else if (codigo == 401) {
      mensaje = MensajesPerfil.sesionInvalida;
    } else if (codigo == 403) {
      mensaje = MensajesPerfil.cuentaDesactivada;
    } else if (codigo == 404) {
      mensaje = MensajesPerfil.sinPerfil;
    } else if (codigo >= 500) {
      mensaje = deLaApi ?? porDefecto503;
    } else {
      mensaje = MensajesPerfil.errorGeneral;
    }
    return ApiException(codigo, mensaje);
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
