import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/perfil/data/cuenta_con_reservas.dart';
import 'package:servia/features/perfil/data/perfil_cliente_service.dart';
import 'package:servia/features/perfil/mensajes.dart';

PerfilClienteService servicio(
  Future<http.Response> Function(http.Request) responder,
) => PerfilClienteService(
  api: ApiClient(
    client: MockClient(responder),
    limite: const Duration(seconds: 1),
  ),
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

Map<String, dynamic> error(int estado, String mensaje, String nombre) => {
  'statusCode': estado,
  'message': mensaje,
  'error': nombre,
};

/// Cuerpo del 409 de `DELETE /usuarios/yo` (Servia_BE#116).
const conflicto = {
  'statusCode': 409,
  'message':
      'No puedes eliminar tu cuenta porque tienes reservas pendientes o '
      'confirmadas: SRV-AAAAAA, SRV-BBBBBB. Cancélalas o espera a que '
      'terminen.',
  'error': 'Conflict',
  'total': 2,
  'reservas': [
    {
      'id': 'r1',
      'folio': 'SRV-AAAAAA',
      'estado': 'pendiente',
      'inicio': '2026-11-25T16:30:00.000Z',
    },
    {
      'id': 'r2',
      'folio': 'SRV-BBBBBB',
      'estado': 'confirmada',
      'inicio': '2026-12-02T01:00:00.000Z',
    },
  ],
};

void main() {
  group('eliminarCuenta: DELETE /usuarios/yo (BE#116)', () {
    test('manda Bearer, sin cuerpo, y 204 termina sin error', () async {
      late http.Request visto;
      final s = servicio((r) async {
        visto = r;
        return http.Response('', 204);
      });
      await s.eliminarCuenta('tok');
      expect(visto.method, 'DELETE');
      expect(visto.url.path, '/usuarios/yo');
      expect(visto.headers['Authorization'], 'Bearer tok');
      expect(visto.body, isEmpty);
    });

    test('409 trae el mensaje, el total y las reservas por atender', () async {
      final s = servicio((_) async => json(409, conflicto));
      final e = await fallo(() => s.eliminarCuenta('tok'));
      expect(e, isA<CuentaConReservasException>());
      final c = e as CuentaConReservasException;
      expect(c.statusCode, 409);
      expect(c.mensaje, conflicto['message']);
      expect(c.total, 2);
      expect(c.reservas, hasLength(2));
      expect(c.reservas[0].id, 'r1');
      expect(c.reservas[0].folio, 'SRV-AAAAAA');
      expect(c.reservas[0].estado, 'pendiente');
      expect(c.reservas[0].inicio, DateTime.utc(2026, 11, 25, 16, 30));
      expect(c.reservas[1].estado, 'confirmada');
      expect(c.reservas[1].inicio.isUtc, isTrue);
    });

    test(
      '409 malformado o sin lista conserva el mensaje y no truena',
      () async {
        final s = servicio(
          (_) async => json(409, {
            'statusCode': 409,
            'message': 'No puedes eliminar tu cuenta: y 3 más.',
            'error': 'Conflict',
            'total': 13,
            'reservas': [
              {'id': 'r1'},
              'x',
              {
                'id': 'r2',
                'folio': 'SRV-CCCCCC',
                'estado': 'pendiente',
                'inicio': 'no-es-fecha',
              },
            ],
          }),
        );
        final e = await fallo(() => s.eliminarCuenta('tok'));
        final c = e as CuentaConReservasException;
        expect(c.mensaje, 'No puedes eliminar tu cuenta: y 3 más.');
        expect(c.total, 13);
        expect(c.reservas, isEmpty);
        final sinCuerpo = servicio((_) async => http.Response('', 409));
        final e2 = await fallo(() => sinCuerpo.eliminarCuenta('tok'));
        expect(e2.statusCode, 409);
        expect(e2.mensaje, MensajesPerfil.eliminarConReservas);
      },
    );

    test('401 y 403 con mensajes del módulo', () async {
      final e401 = await fallo(
        () =>
            servicio((_) async => json(401, error(401, 'x', 'Unauthorized')))
                .eliminarCuenta('tok'),
      );
      expect(e401.statusCode, 401);
      expect(e401.mensaje, MensajesPerfil.sesionInvalida);
      final e403 = await fallo(
        () =>
            servicio((_) async => json(403, error(403, 'x', 'Forbidden')))
                .eliminarCuenta('tok'),
      );
      expect(e403.statusCode, 403);
      expect(e403.mensaje, MensajesPerfil.soloClientes);
    });

    test('503 conserva el mensaje de la API; sin cuerpo usa el de la app', () async {
      for (final mensaje in [
        'No se pudo eliminar tu cuenta. Vuelve a intentarlo en unos minutos.',
        'No se pudo eliminar tu usuario. Vuelve a intentarlo en unos minutos.',
      ]) {
        final e = await fallo(
          () => servicio(
            (_) async => json(503, error(503, mensaje, 'Service Unavailable')),
          ).eliminarCuenta('tok'),
        );
        expect(e.statusCode, 503);
        expect(e.mensaje, mensaje);
      }
      final e = await fallo(
        () =>
            servicio((_) async => http.Response('', 503)).eliminarCuenta('tok'),
      );
      expect(e.mensaje, MensajesPerfil.eliminarNoSePudo);
    });
  });
}
