import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/reservas/data/reservas_service.dart';

import 'datos_detalle.dart';

ReservasService conRespuesta(http.Response respuesta) =>
    ReservasService(api: ApiClient(client: MockClient((_) async => respuesta)));

void main() {
  test(
    'obtenerMia consulta la ruta propia con token y lee el detalle',
    () async {
      late http.Request enviada;
      final servicio = ReservasService(
        api: ApiClient(
          client: MockClient((r) async {
            enviada = r;
            return http.Response(jsonEncode(datosDetalle), 200);
          }),
        ),
      );
      final r = await servicio.obtenerMia('token-cliente', 'r1');
      expect(enviada.method, 'GET');
      expect(enviada.url.path, '/reservas/mias/r1');
      expect(enviada.headers['Authorization'], 'Bearer token-cliente');
      expect(r.id, 'r1');
      expect(r.folio, 'SRV-7KQ2MX');
      expect(r.estado, 'pendiente');
      expect(r.inicio, DateTime.utc(2026, 11, 10, 5, 30));
      expect(r.fin, DateTime.utc(2026, 11, 10, 7));
      expect(r.servicio, 'Corte de cabello');
      expect(r.precio, 150.5);
      expect(r.duracionMin, 90);
      expect(r.negocio, 'Barbería Central');
      expect(r.direccionTexto, 'Juárez 10, León, Guanajuato');
      expect(r.telefono, '4771234567');
      expect(r.observaciones, 'Corte con tijera.');
      expect(r.motivo, isNull);
      expect(r.venceEn, DateTime.utc(2026, 11, 10, 3, 30));
      expect(r.cancelable, isTrue);
      expect(r.cancelableHasta, r.inicio);
    },
  );

  test('obtenerMia conserva los campos nulos del contrato', () async {
    final servicio = conRespuesta(
      http.Response(
        jsonEncode({
          ...datosDetalle,
          'servicio': {
            'id': 's1',
            'nombre': 'Corte',
            'precio': null,
            'duracionMin': null,
          },
          'venceEn': null,
          'observaciones': null,
          'motivo': 'Sin personal.',
          'cancelable': false,
          'cancelableHasta': null,
        }),
        200,
      ),
    );
    final r = await servicio.obtenerMia('token', 'r1');
    expect(r.precio, isNull);
    expect(r.duracionMin, isNull);
    expect(r.venceEn, isNull);
    expect(r.observaciones, isNull);
    expect(r.motivo, 'Sin personal.');
    expect(r.cancelable, isFalse);
    expect(r.cancelableHasta, isNull);
  });

  for (final codigo in [400, 401, 403, 404, 500]) {
    test('obtenerMia propaga el código $codigo', () async {
      await expectLater(
        conRespuesta(http.Response('{}', codigo)).obtenerMia('token', 'ajena'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'código', codigo),
        ),
      );
    });
  }

  test('obtenerMia rechaza cuerpos mal formados', () async {
    for (final cuerpo in [
      '[]',
      '{}',
      jsonEncode({...datosDetalle, 'cancelable': 'sí'}),
    ]) {
      await expectLater(
        conRespuesta(http.Response(cuerpo, 200)).obtenerMia('token', 'r1'),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('obtenerMia propaga el tiempo agotado', () async {
    final servicio = ReservasService(
      api: ApiClient(
        limite: const Duration(milliseconds: 10),
        client: MockClient((_) => Completer<http.Response>().future),
      ),
    );
    await expectLater(
      servicio.obtenerMia('token', 'r1'),
      throwsA(isA<TimeoutException>()),
    );
  });
}
