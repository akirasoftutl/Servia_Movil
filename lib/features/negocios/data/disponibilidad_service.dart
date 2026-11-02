import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'disponibilidad.dart';
import 'lectura_json.dart';
import 'negocios_service.dart';

class DisponibilidadService {
  DisponibilidadService({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<List<DiaDisponibilidad>> obtenerDias(
    String negocioId,
    String servicioId,
  ) async => (await _consultar(
    negocioId,
    servicioId,
  )).map((dato) => DiaDisponibilidad.fromJson(leerObjeto(dato))).toList();

  Future<List<HoraDisponibilidad>> obtenerHoras(
    String negocioId,
    String servicioId,
    String fecha,
  ) async => (await _consultar(
    negocioId,
    servicioId,
    fecha: fecha,
  )).map((dato) => HoraDisponibilidad.fromJson(leerObjeto(dato))).toList();

  Future<List<dynamic>> _consultar(
    String negocioId,
    String servicioId, {
    String? fecha,
  }) async {
    if (!esIdValido(negocioId) || !esIdValido(servicioId)) {
      throw const ApiException(404, 'Este servicio ya no está disponible.');
    }
    final ruta = Uri(
      path: '/negocios/$negocioId/servicios/$servicioId/disponibilidad',
      queryParameters: fecha == null ? null : {'fecha': fecha},
    );
    // MVP-17 es público: sin Firebase ni token. ApiClient aplica su tiempo límite.
    final respuesta = await _api.get(ruta.toString());
    if (respuesta.statusCode != 200) {
      throw ApiException(
        respuesta.statusCode,
        'No se pudo consultar la disponibilidad.',
      );
    }
    final datos = jsonDecode(respuesta.body);
    if (datos is! List) {
      throw const FormatException('Disponibilidad inválida.');
    }
    return datos;
  }
}
