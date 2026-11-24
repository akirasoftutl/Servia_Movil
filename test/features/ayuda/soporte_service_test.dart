import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/ayuda/data/soporte_service.dart';

SoporteService servicio(
  Future<http.Response> Function(http.Request) responder, {
  Duration limite = const Duration(seconds: 1),
}) => SoporteService(
  api: ApiClient(client: MockClient(responder), limite: limite),
);

http.Response json(int estado, Object cuerpo) => http.Response(
  jsonEncode(cuerpo),
  estado,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<ApiException> fallo(Future<Object?> Function() accion) async {
  try {
    await accion();
  } on ApiException catch (e) {
    return e;
  }
  fail('se esperaba ApiException');
}

/// Cuerpos tal como los responde Servia_BE (soporte.controller.ts y
/// exceptionFactoryValidacion): 400 con `message` en lista y `camposConError`,
/// 429 con `message` en texto.
Map<String, Object> error400(List<String> mensajes) => {
  'statusCode': 400,
  'message': mensajes,
  'error': 'Bad Request',
  'camposConError': ['asunto'],
};

void main() {
  group('enviar (POST /soporte/reportes)', () {
    test(
      'manda asunto y descripcion recortados, con el token, y lee el 201',
      () async {
        late http.Request visto;
        final s = servicio((r) async {
          visto = r;
          return json(201, {
            'id': 'abc',
            'asunto': 'No carga mi reserva',
            'estado': 'abierto',
            'creadaEn': '2026-11-24T20:05:00.000Z',
          });
        });
        final creado = await s.enviar(
          'tok',
          asunto: '  No carga mi reserva  ',
          descripcion: '\n La pantalla se queda en blanco al abrirla. ',
        );
        expect(visto.method, 'POST');
        expect(visto.url.path, '/soporte/reportes');
        expect(visto.headers['Authorization'], 'Bearer tok');
        // El cuerpo lleva solo los dos campos (la API rechaza campos extra).
        expect(jsonDecode(visto.body), {
          'asunto': 'No carga mi reserva',
          'descripcion': 'La pantalla se queda en blanco al abrirla.',
        });
        expect(creado!.id, 'abc');
        expect(creado.asunto, 'No carga mi reserva');
        expect(creado.estado, 'abierto');
        expect(creado.creadaEn, DateTime.utc(2026, 11, 24, 20, 5));
      },
    );

    test(
      'un 201 con cuerpo ilegible cuenta como enviado (devuelve null)',
      () async {
        final s = servicio((_) async => http.Response('no es json', 201));
        expect(
          await s.enviar('t', asunto: 'Asunto', descripcion: 'x' * 20),
          isNull,
        );
      },
    );

    test(
      '400: muestra el mensaje de la API, aunque llegue como lista',
      () async {
        final s = servicio(
          (_) async => json(
            400,
            error400([
              'El asunto debe tener entre 5 y 100 caracteres sin espacios en los extremos.',
            ]),
          ),
        );
        final e = await fallo(
          () => s.enviar('t', asunto: 'Hola', descripcion: 'x' * 20),
        );
        expect(e.statusCode, 400);
        expect(
          e.mensaje,
          'El asunto debe tener entre 5 y 100 caracteres sin espacios en los extremos.',
        );
      },
    );

    test('400 sin mensaje legible usa el texto genérico en español', () async {
      final s = servicio((_) async => http.Response('<html>', 400));
      final e = await fallo(
        () => s.enviar('t', asunto: 'Hola!!', descripcion: 'x' * 20),
      );
      expect(e.statusCode, 400);
      expect(
        e.mensaje,
        'Revisa el asunto y la descripción e inténtalo de nuevo.',
      );
    });

    test('429: muestra el mensaje de la API', () async {
      final s = servicio(
        (_) async => json(429, {
          'statusCode': 429,
          'message': 'Enviaste demasiados reportes; inténtalo más tarde.',
        }),
      );
      final e = await fallo(
        () => s.enviar('t', asunto: 'Asunto', descripcion: 'x' * 20),
      );
      expect(e.statusCode, 429);
      expect(e.mensaje, 'Enviaste demasiados reportes; inténtalo más tarde.');
    });

    test('429 sin cuerpo usa el mismo texto del contrato', () async {
      final s = servicio((_) async => http.Response('', 429));
      final e = await fallo(
        () => s.enviar('t', asunto: 'Asunto', descripcion: 'x' * 20),
      );
      expect(e.mensaje, 'Enviaste demasiados reportes; inténtalo más tarde.');
    });

    test(
      '401 y 403 y 500 llegan como ApiException con texto en español',
      () async {
        for (final codigo in [401, 500]) {
          final s = servicio((_) async => json(codigo, {'message': 'x'}));
          final e = await fallo(
            () => s.enviar('t', asunto: 'Asunto', descripcion: 'x' * 20),
          );
          expect(e.statusCode, codigo);
          expect(e.mensaje, isNot('x'));
          expect(e.mensaje, isNotEmpty);
        }
      },
    );

    test('403: muestra el mensaje de la API (cuenta desactivada)', () async {
      final s = servicio(
        (_) async => json(403, {
          'statusCode': 403,
          'message': 'La cuenta está desactivada.',
        }),
      );
      final e = await fallo(
        () => s.enviar('t', asunto: 'Asunto', descripcion: 'x' * 20),
      );
      expect(e.statusCode, 403);
      expect(e.mensaje, 'La cuenta está desactivada.');
    });

    test('el tiempo agotado sale como TimeoutException', () async {
      final s = servicio(
        (_) => Completer<http.Response>().future,
        limite: const Duration(milliseconds: 20),
      );
      await expectLater(
        s.enviar('t', asunto: 'Asunto', descripcion: 'x' * 20),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('listarMios (GET /soporte/reportes/mios)', () {
    test(
      'pide la lista de la cuenta del token, sin uid ni parámetros',
      () async {
        late http.Request visto;
        final s = servicio((r) async {
          visto = r;
          return json(200, [
            {
              'id': 'r2',
              'asunto': 'Segundo',
              'estado': 'abierto',
              'creadaEn': '2026-11-24T21:00:00.000Z',
            },
            {
              'id': 'r1',
              'asunto': 'Primero',
              'estado': 'abierto',
              'creadaEn': '2026-11-24T20:00:00.000Z',
            },
          ]);
        });
        final lista = await s.listarMios('tok');
        expect(visto.method, 'GET');
        expect(visto.url.path, '/soporte/reportes/mios');
        expect(visto.url.query, isEmpty);
        expect(visto.headers['Authorization'], 'Bearer tok');
        // Se conserva el orden de la API (más reciente primero).
        expect(lista.map((r) => r.asunto), ['Segundo', 'Primero']);
        expect(lista.first.creadaEn, DateTime.utc(2026, 11, 24, 21));
      },
    );

    test('lista vacía', () async {
      final s = servicio((_) async => json(200, <Object>[]));
      expect(await s.listarMios('t'), isEmpty);
    });

    test('401 avisa de la sesión y 500 del error al cargar', () async {
      final sesion = await fallo(
        () =>
            servicio((_) async => json(401, {'message': 'x'})).listarMios('t'),
      );
      expect(sesion.statusCode, 401);
      final caido = await fallo(
        () =>
            servicio((_) async => json(500, {'message': 'x'})).listarMios('t'),
      );
      expect(
        caido.mensaje,
        'No pudimos cargar tus reportes. Intenta de nuevo.',
      );
    });

    test('un cuerpo que no es lista sale como FormatException', () async {
      final s = servicio((_) async => json(200, {'items': []}));
      await expectLater(s.listarMios('t'), throwsA(isA<FormatException>()));
    });
  });
}
