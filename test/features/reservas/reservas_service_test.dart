import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/reservas/data/reservas_service.dart';

const _respuesta = {
  'id': 'r1',
  'folio': 'SRV-7KQ2MX',
  'estado': 'pendiente',
  'inicio': '2026-11-10T16:00:00.000Z',
  'fin': '2026-11-10T17:00:00.000Z',
  'precio': 150,
  'duracionMin': 60,
  'venceEn': '2026-11-10T14:00:00.000Z',
};

const _solicitud = SolicitudReserva(
  negocioId: 'n1',
  servicioId: 's1',
  inicio: '2026-11-10T10:00:00-06:00',
  observaciones: '  Llego 5 minutos antes.  ',
);

ReservasService _con(Future<http.Response> Function(http.Request) f) =>
    ReservasService(api: ApiClient(client: MockClient(f)));

void main() {
  test('POST /reservas con token y el cuerpo del contrato de la API', () async {
    late http.Request enviada;
    final servicio = _con((r) async {
      enviada = r;
      return http.Response(jsonEncode(_respuesta), 201);
    });
    final reserva = await servicio.crear('tok', _solicitud);
    expect(enviada.method, 'POST');
    expect(enviada.url.path, '/reservas');
    expect(enviada.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(enviada.body), {
      'negocioId': 'n1',
      'servicioId': 's1',
      'inicio': '2026-11-10T10:00:00-06:00',
      'observaciones': 'Llego 5 minutos antes.',
    });
    expect(reserva.folio, 'SRV-7KQ2MX');
    expect(reserva.estado, 'pendiente');
    expect(reserva.duracionMin, 60);
    expect(reserva.precio, 150);
  });

  test('sin observaciones no manda el campo', () async {
    late http.Request enviada;
    final servicio = _con((r) async {
      enviada = r;
      return http.Response(jsonEncode(_respuesta), 201);
    });
    await servicio.crear(
      'tok',
      const SolicitudReserva(
        negocioId: 'n1',
        servicioId: 's1',
        inicio: '2026-11-10T10:00:00-06:00',
        observaciones: '   ',
      ),
    );
    expect(jsonDecode(enviada.body), isNot(contains('observaciones')));
  });

  for (final codigo in [400, 401, 403, 404, 409, 500]) {
    test('el código $codigo llega como ApiException con ese código', () async {
      final servicio = _con((_) async => http.Response('{}', codigo));
      await expectLater(
        servicio.crear('tok', _solicitud),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'código', codigo),
        ),
      );
    });
  }

  test('una respuesta 201 sin folio o mal formada es FormatException', () async {
    for (final cuerpo in [
      '[]',
      jsonEncode({..._respuesta, 'folio': ''}),
      jsonEncode({..._respuesta, 'precio': '150'}),
      jsonEncode({..._respuesta, 'venceEn': 'ayer'}),
    ]) {
      final servicio = _con((_) async => http.Response(cuerpo, 201));
      await expectLater(
        servicio.crear('tok', _solicitud),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('el tiempo agotado se propaga como TimeoutException', () async {
    final servicio = ReservasService(
      api: ApiClient(
        limite: const Duration(milliseconds: 10),
        client: MockClient((_) => Completer<http.Response>().future),
      ),
    );
    await expectLater(
      servicio.crear('tok', _solicitud),
      throwsA(isA<TimeoutException>()),
    );
  });
}
