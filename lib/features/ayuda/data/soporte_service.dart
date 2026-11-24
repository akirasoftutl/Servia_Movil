import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../negocios/data/lectura_json.dart';
import '../mensajes.dart';
import 'reporte.dart';

/// Reportes de soporte del cliente con la API (`/soporte/reportes`,
/// Servia_BE#101 y Servia_BE#104). La app nunca escribe directo en Firestore.
class SoporteService {
  SoporteService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Envía un reporte (`POST /soporte/reportes`). El uid y el tipo salen del
  /// token. Devuelve `null` si la API respondió 201 pero el cuerpo no se
  /// pudo leer: el reporte sí se creó y no debe reenviarse.
  /// Lanza [ApiException] con el código HTTP y el texto en español; la falta
  /// de red llega como la excepción del cliente HTTP o `TimeoutException`.
  Future<Reporte?> enviar(
    String token, {
    required String asunto,
    required String descripcion,
  }) async {
    final respuesta = await _api.post(
      '/soporte/reportes',
      token: token,
      body: jsonEncode({
        'asunto': asunto.trim(),
        'descripcion': descripcion.trim(),
      }),
    );
    if (respuesta.statusCode == 201) {
      try {
        return Reporte.fromJson(leerObjeto(jsonDecode(respuesta.body)));
      } on FormatException {
        return null;
      }
    }
    throw ApiException(
      respuesta.statusCode,
      _mensajeDeEnvio(respuesta.statusCode, respuesta.body),
    );
  }

  /// Los últimos 50 reportes de la cuenta del token, el más reciente primero
  /// (`GET /soporte/reportes/mios`, RN-46).
  Future<List<Reporte>> listarMios(String token) async {
    final respuesta = await _api.get('/soporte/reportes/mios', token: token);
    if (respuesta.statusCode != 200) {
      throw ApiException(
        respuesta.statusCode,
        respuesta.statusCode == 401
            ? MensajesAyuda.sesionVencida
            : MensajesAyuda.errorLista,
      );
    }
    final datos = jsonDecode(respuesta.body);
    if (datos is! List) throw const FormatException('Se esperaba una lista.');
    return [for (final item in datos) Reporte.fromJson(leerObjeto(item))];
  }

  String _mensajeDeEnvio(int codigo, String cuerpo) {
    switch (codigo) {
      case 400:
        return _mensajeDeLaApi(cuerpo) ?? MensajesAyuda.datosInvalidos;
      case 401:
        return MensajesAyuda.sesionVencida;
      case 403:
        return _mensajeDeLaApi(cuerpo) ?? MensajesAyuda.cuentaNoPermitida;
      case 429:
        return _mensajeDeLaApi(cuerpo) ?? MensajesAyuda.limiteReportes;
    }
    return codigo >= 500 ? MensajesAyuda.errorApi : MensajesAyuda.errorEnvio;
  }

  /// En 400 `message` llega como lista; en 403 y 429, como texto.
  String? _mensajeDeLaApi(String cuerpo) {
    try {
      final datos = jsonDecode(cuerpo);
      if (datos is Map) {
        final mensaje = datos['message'];
        if (mensaje is List && mensaje.isNotEmpty && mensaje.first is String) {
          return mensaje.first as String;
        }
        if (mensaje is String && mensaje.trim().isNotEmpty) return mensaje;
      }
    } on FormatException {
      // Sin JSON se usa el texto genérico.
    }
    return null;
  }
}
