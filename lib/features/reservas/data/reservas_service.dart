import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../negocios/data/lectura_json.dart';
import 'detalle_reserva.dart';
import 'reserva_creada.dart';
import 'reserva_resumen.dart';

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

  /// Lista las reservas del cliente (`GET /reservas/mias`) paginadas por cursor.
  /// [vista] es `proximas` o `historial`, según la tabla activa.
  /// Lanza [ApiException] con el código HTTP y [FormatException] si el cuerpo
  /// no respeta el contrato.
  Future<PaginaReservas> listarMias(
    String token, {
    String vista = 'proximas',
    String? cursor,
  }) async {
    final query = <String, String>{'vista': vista};
    if (cursor != null) query['cursor'] = cursor;
    final uri = Uri(path: '/reservas/mias', queryParameters: query);
    final respuesta = await _api.get('$uri', token: token);
    if (respuesta.statusCode != 200) {
      throw ApiException(
        respuesta.statusCode,
        'No se pudieron cargar tus reservas.',
      );
    }
    return PaginaReservas.fromJson(leerObjeto(jsonDecode(respuesta.body)));
  }

  /// RN-45: solo se consulta el recurso propio del cliente autenticado.
  Future<DetalleReserva> obtenerMia(String token, String id) async {
    final respuesta = await _api.get(
      '/reservas/mias/${Uri.encodeComponent(id)}',
      token: token,
    );
    if (respuesta.statusCode != 200) {
      throw ApiException(respuesta.statusCode, 'No se pudo cargar tu reserva.');
    }
    return DetalleReserva.fromJson(leerObjeto(jsonDecode(respuesta.body)));
  }
}
