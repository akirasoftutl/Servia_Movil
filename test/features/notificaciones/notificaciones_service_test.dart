import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/notificaciones/data/aviso.dart';
import 'package:servia/features/notificaciones/data/notificaciones_service.dart';

NotificacionesService servicioCon(
  Future<http.Response> Function(http.Request) responder,
) => NotificacionesService(api: ApiClient(client: MockClient(responder)));

Map<String, dynamic> avisoJson({
  String id = 'a1',
  bool leida = false,
  String creadaEn = '2026-11-22T10:05:00Z',
}) => <String, dynamic>{
  'id': id,
  'tipo': 'reserva.confirmada',
  'titulo': 'Reserva confirmada',
  'cuerpo': 'Tu reserva quedó confirmada.',
  'leida': leida,
  'creadaEn': creadaEn,
  'reservaId': 'r1',
};

String paginaJson({
  List<Map<String, dynamic>>? items,
  int noLeidas = 2,
  String? siguiente,
}) => jsonEncode(<String, dynamic>{
  'items': items ?? [avisoJson(), avisoJson(id: 'a2', leida: true)],
  'noLeidas': noLeidas,
  'siguiente': siguiente,
});

void main() {
  group('NotificacionesService', () {
    test(
      'GET /notificaciones envía token, límite y cursor y parsea la página',
      () async {
        final servicio = servicioCon((peticion) async {
          expect(peticion.method, 'GET');
          expect(peticion.url.path, '/notificaciones');
          expect(peticion.url.queryParameters['limite'], '20');
          expect(peticion.url.queryParameters['cursor'], 'cursor-2');
          expect(peticion.headers['Authorization'], 'Bearer token-api');
          return http.Response(paginaJson(siguiente: 'cursor-3'), 200);
        });
        final pagina = await servicio.listar('token-api', cursor: 'cursor-2');
        expect(pagina.items, hasLength(2));
        expect(pagina.items.first.id, 'a1');
        expect(pagina.items.first.leida, isFalse);
        expect(pagina.noLeidas, 2);
        expect(pagina.siguiente, 'cursor-3');
      },
    );

    test('GET sin cursor omite el parámetro', () async {
      final servicio = servicioCon((peticion) async {
        expect(peticion.url.queryParameters.containsKey('cursor'), isFalse);
        return http.Response(paginaJson(), 200);
      });
      await servicio.listar('token-api');
    });

    test('POST /notificaciones/tokens registra plataforma android', () async {
      final servicio = servicioCon((peticion) async {
        expect(peticion.method, 'POST');
        expect(peticion.url.path, '/notificaciones/tokens');
        expect(peticion.headers['Authorization'], 'Bearer token-api');
        expect(jsonDecode(peticion.body), <String, dynamic>{
          'token': 'fcm-123',
          'plataforma': 'android',
        });
        return http.Response('', 204);
      });
      await servicio.registrarToken('token-api', 'fcm-123');
    });

    test(
      'DELETE /notificaciones/tokens envía el token FCM en el body',
      () async {
        final servicio = servicioCon((peticion) async {
          expect(peticion.method, 'DELETE');
          expect(peticion.url.path, '/notificaciones/tokens');
          expect(peticion.headers['Authorization'], 'Bearer token-api');
          expect(jsonDecode(peticion.body), <String, dynamic>{
            'token': 'fcm-123',
          });
          return http.Response('', 204);
        });
        await servicio.desactivarToken('token-api', 'fcm-123');
      },
    );

    test('PATCH /notificaciones/:id/leida codifica el id', () async {
      final servicio = servicioCon((peticion) async {
        expect(peticion.method, 'PATCH');
        expect(peticion.url.path, '/notificaciones/a%2Fb/leida');
        expect(peticion.headers['Authorization'], 'Bearer token-api');
        return http.Response('', 204);
      });
      await servicio.marcarLeida('token-api', 'a/b');
    });

    test('errores HTTP se exponen como ApiException', () async {
      for (final estado in [401, 500]) {
        final servicio = servicioCon(
          (_) async => http.Response('{"mensaje":"secreto"}', estado),
        );
        await expectLater(
          servicio.listar('token-api'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'estado', estado)
                .having(
                  (e) => e.mensaje,
                  'mensaje',
                  isNot(contains('secreto')),
                ),
          ),
        );
        await expectLater(
          servicio.registrarToken('token-api', 'fcm'),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          servicio.desactivarToken('token-api', 'fcm'),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          servicio.marcarLeida('token-api', 'a1'),
          throwsA(isA<ApiException>()),
        );
      }
    });

    test('respuestas mal formadas se rechazan', () async {
      for (final cuerpo in ['[]', 'null', '{}', 'no json']) {
        final servicio = servicioCon((_) async => http.Response(cuerpo, 200));
        await expectLater(servicio.listar('token-api'), throwsFormatException);
      }
      final servicio = servicioCon((_) async => http.Response('', 204));
      await expectLater(
        servicio.listar('token-api'),
        throwsA(isA<ApiException>()),
      );
    });

    test('Aviso.fromJson valida la fecha', () {
      final json = avisoJson();
      expect(
        () => Aviso.fromJson({...json, 'creadaEn': 'no-fecha'}),
        throwsFormatException,
      );
    });
  });
}
