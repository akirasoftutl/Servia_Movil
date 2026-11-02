import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../negocios/data/lectura_json.dart';
import 'reserva_creada.dart';

/// Datos de la solicitud de reserva (`POST /reservas`).
class SolicitudReserva {
  const SolicitudReserva({
    required this.negocioId,
    required this.servicioId,
    required this.inicio,
    this.observaciones,
  });

  final String negocioId;
  final String servicioId;

  /// ISO 8601 con zona (por ejemplo `2026-11-10T10:00:00-06:00`).
  final String inicio;
  final String? observaciones;

  Map<String, dynamic> toJson() {
    final texto = observaciones?.trim() ?? '';
    return {
      'negocioId': negocioId,
      'servicioId': servicioId,
      'inicio': inicio,
      if (texto.isNotEmpty) 'observaciones': texto,
    };
  }
}

class ReservasService {
  ReservasService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Crea la reserva Pendiente del cliente del token.
  /// Lanza [ApiException] con el código HTTP (400, 401, 403, 404, 409...).
  /// El tiempo agotado llega como `TimeoutException` desde [ApiClient].
  Future<ReservaCreada> crear(String token, SolicitudReserva solicitud) async {
    final respuesta = await _api.post(
      '/reservas',
      token: token,
      body: jsonEncode(solicitud.toJson()),
    );
    if (respuesta.statusCode != 201) {
      throw ApiException(
        respuesta.statusCode,
        'No se pudo enviar la solicitud.',
      );
    }
    final datos = jsonDecode(respuesta.body);
    return ReservaCreada.fromJson(leerObjeto(datos));
  }
}
