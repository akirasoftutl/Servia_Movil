import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/disponibilidad_service.dart';
import 'package:servia/features/reservas/data/detalle_reserva.dart';
import 'package:servia/features/reservas/data/reservas_service.dart';

import 'escenario_reprogramar.dart';

ReservasService servicio(Future<http.Response> Function(http.Request) f) =>
    ReservasService(api: ApiClient(client: MockClient(f)));

void main() {
  group('DetalleReserva lee los campos de BE#117', () {
    test('reprogramable, reprogramableHasta y motivo, con ids', () {
      final d = DetalleReserva.fromJson(detalleApi());
      expect(d.reprogramable, isTrue);
      expect(d.reprogramableHasta, DateTime.utc(2026, 11, 10, 16));
      expect(d.motivoNoReprogramable, isNull);
      expect(d.negocioId, 'n1');
      expect(d.servicioId, 's1');
    });

    test('no reprogramable: conserva el motivo en español de la API', () {
      final d = DetalleReserva.fromJson(
        detalleApi(
          estado: 'confirmada',
          reprogramable: false,
          motivoNoReprogramable:
              'Solo puedes cambiar una reserva confirmada hasta 24 horas antes de la cita.',
        ),
      );
      expect(d.reprogramable, isFalse);
      expect(
        d.motivoNoReprogramable,
        'Solo puedes cambiar una reserva confirmada hasta 24 horas antes de la cita.',
      );
    });

    test('una respuesta sin los campos nuevos no ofrece cambiar nada', () {
      final json = detalleApi()
        ..remove('reprogramable')
        ..remove('reprogramableHasta')
        ..remove('motivoNoReprogramable');
      expect(DetalleReserva.fromJson(json).reprogramable, isFalse);
    });
  });

  group('PATCH /reservas/mias/{id}/reprogramar', () {
    test('manda solo inicio (sin servicioId) y lee la respuesta real', () async {
      late http.Request enviada;
      final reservas = servicio((r) async {
        enviada = r;
        return http.Response(EscenarioReprogramar.exito(), 200);
      });
      final resultado = await reservas.reprogramar(
        'token',
        'r1',
        '2026-11-12T09:30:00-06:00',
      );
      expect(enviada.method, 'PATCH');
      expect(enviada.url.path, '/reservas/mias/r1/reprogramar');
      expect(enviada.headers['Authorization'], 'Bearer token');
      expect(jsonDecode(enviada.body), {'inicio': '2026-11-12T09:30:00-06:00'});
      expect(resultado.reserva.estado, 'pendiente');
      expect(resultado.reserva.folio, 'SRV-7KQ2MX');
      expect(resultado.reserva.inicio, DateTime.utc(2026, 11, 12, 15, 30));
      expect(resultado.reprogramadaEn, DateTime.utc(2026, 11, 3, 16, 15));
    });

    test('con otro servicio manda servicioId', () async {
      late http.Request enviada;
      final reservas = servicio((r) async {
        enviada = r;
        return http.Response(EscenarioReprogramar.exito(), 200);
      });
      await reservas.reprogramar(
        'token',
        'r1',
        '2026-11-12T09:30:00-06:00',
        servicioId: 's2',
      );
      expect(jsonDecode(enviada.body), {
        'inicio': '2026-11-12T09:30:00-06:00',
        'servicioId': 's2',
      });
    });

    test('400 y 409 conservan el mensaje de la API; el resto, uno claro', () async {
      for (final (codigo, nombre, mensaje) in [
        (400, 'Bad Request', 'No hay cambios: elige otra fecha, otra hora u otro servicio.'),
        (409, 'Conflict', 'El horario elegido ya no está disponible. Elige otro horario.'),
        (409, 'Conflict', 'Solo puedes cambiar una reserva confirmada hasta 24 horas antes de la cita.'),
      ]) {
        final reservas = servicio(
          (_) async => http.Response(errorNest(codigo, mensaje, nombre), codigo),
        );
        await expectLater(
          reservas.reprogramar('token', 'r1', '2026-11-12T09:30:00-06:00'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'código', codigo)
                .having((e) => e.mensaje, 'mensaje', mensaje),
          ),
        );
      }
    });

    test('un mensaje que no es texto (lista de validación) no se muestra tal cual', () async {
      final reservas = servicio(
        (_) async => http.Response(
          jsonEncode({'message': ['inicio inválido'], 'statusCode': 400}),
          400,
        ),
      );
      await expectLater(
        reservas.reprogramar('token', 'r1', 'x'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.mensaje,
            'mensaje',
            'No se pudo cambiar tu reserva. Inténtalo de nuevo.',
          ),
        ),
      );
    });

    test('404, 500 y cuerpo no JSON salen como ApiException; el tiempo, como TimeoutException', () async {
      for (final codigo in [404, 500]) {
        await expectLater(
          servicio((_) async => http.Response('no es JSON', codigo))
              .reprogramar('token', 'r1', 'x'),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'c', codigo)),
        );
      }
      final lenta = ReservasService(
        api: ApiClient(
          limite: const Duration(milliseconds: 10),
          client: MockClient((_) => Completer<http.Response>().future),
        ),
      );
      await expectLater(
        lenta.reprogramar('token', 'r1', 'x'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('un 200 con cuerpo inválido es FormatException', () async {
      await expectLater(
        servicio((_) async => http.Response('{}', 200))
            .reprogramar('token', 'r1', 'x'),
        throwsFormatException,
      );
    });
  });

  group('GET /reservas/mias/{id}/disponibilidad', () {
    DisponibilidadService conRuta(List<http.Request> vistas) =>
        DisponibilidadService(
          api: ApiClient(
            client: MockClient((r) async {
              vistas.add(r);
              return http.Response(
                jsonEncode(
                  r.url.queryParameters.containsKey('fecha')
                      ? [
                          {'hora': '10:00', 'disponible': true},
                        ]
                      : [
                          {'fecha': '2026-11-12', 'disponible': true},
                        ],
                ),
                200,
              );
            }),
          ),
        );

    test('usa la ruta de la reserva con el token del cliente', () async {
      final vistas = <http.Request>[];
      final s = conRuta(vistas);
      final dias = await s.obtenerDiasDeReserva('token', 'r1');
      final horas = await s.obtenerHorasDeReserva(
        'token',
        'r1',
        '2026-11-12',
        servicioId: 's2',
      );
      expect(dias.single.fecha, '2026-11-12');
      expect(horas.single.hora, '10:00');
      expect(vistas.first.url.path, '/reservas/mias/r1/disponibilidad');
      expect(vistas.first.url.query, isEmpty);
      expect(vistas.first.headers['Authorization'], 'Bearer token');
      expect(vistas.last.url.queryParameters, {
        'fecha': '2026-11-12',
        'servicioId': 's2',
      });
    });

    test('propaga el código HTTP', () async {
      final s = DisponibilidadService(
        api: ApiClient(
          client: MockClient((_) async => http.Response('{}', 401)),
        ),
      );
      await expectLater(
        s.obtenerDiasDeReserva('token', 'r1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'c', 401)),
      );
    });
  });
}
