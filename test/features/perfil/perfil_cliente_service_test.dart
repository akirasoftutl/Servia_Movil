import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/perfil/data/perfil_cliente_service.dart';

PerfilClienteService servicio(
  Future<http.Response> Function(http.Request) responder, {
  Duration limite = const Duration(seconds: 1),
}) {
  return PerfilClienteService(
    api: ApiClient(client: MockClient(responder), limite: limite),
  );
}

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

void main() {
  test(
    'obtener hace GET /usuarios/yo con el token y lee los tres datos',
    () async {
      late http.Request visto;
      final s = servicio((r) async {
        visto = r;
        return json(200, {
          'nombre': 'Ana Pérez',
          'correo': 'ana@test.com',
          'telefono': '4771234567',
        });
      });
      final perfil = await s.obtener('tok');
      expect(visto.method, 'GET');
      expect(visto.url.path, '/usuarios/yo');
      expect(visto.headers['Authorization'], 'Bearer tok');
      expect(perfil.nombre, 'Ana Pérez');
      expect(perfil.correo, 'ana@test.com');
      expect(perfil.telefono, '4771234567');
    },
  );

  test(
    'actualizar hace PATCH /usuarios/yo solo con los campos enviados',
    () async {
      late http.Request visto;
      final s = servicio((r) async {
        visto = r;
        return json(200, {
          'nombre': 'Ana Ruiz',
          'correo': 'ana@test.com',
          'telefono': '4770000000',
        });
      });
      final perfil = await s.actualizar(
        'tok',
        nombre: 'Ana Ruiz',
        telefono: '4770000000',
      );
      expect(visto.method, 'PATCH');
      expect(visto.url.path, '/usuarios/yo');
      expect(visto.headers['Authorization'], 'Bearer tok');
      expect(visto.headers['Content-Type'], contains('application/json'));
      expect(jsonDecode(visto.body), {
        'nombre': 'Ana Ruiz',
        'telefono': '4770000000',
      });
      expect(perfil.nombre, 'Ana Ruiz');
    },
  );

  test(
    '409 se traduce a «Ese correo ya está en uso.» con código 409',
    () async {
      final s = servicio((_) async => json(409, {'message': 'x'}));
      final e = await fallo(() => s.actualizar('t', correo: 'otra@test.com'));
      expect(e.statusCode, 409);
      expect(e.mensaje, 'Ese correo ya está en uso.');
    },
  );

  test('400 usa el primer mensaje de la API', () async {
    final s = servicio(
      (_) async => json(400, {
        'message': ['El teléfono debe tener 10 dígitos.', 'otro'],
      }),
    );
    final e = await fallo(() => s.actualizar('t', telefono: '1'));
    expect(e.statusCode, 400);
    expect(e.mensaje, 'El teléfono debe tener 10 dígitos.');
  });

  for (final (codigo, texto) in [
    (401, 'No se pudo verificar tu sesión. Vuelve a iniciar sesión.'),
    (404, 'Tu cuenta no tiene un perfil registrado.'),
    (500, 'La API no está disponible. Intenta más tarde.'),
  ]) {
    test('$codigo → «$texto»', () async {
      final s = servicio((_) async => json(codigo, {'message': 'x'}));
      final e = await fallo(() => s.obtener('t'));
      expect(e.statusCode, codigo);
      expect(e.mensaje, texto);
    });
  }

  test(
    'sin respuesta de la API corta por tiempo límite (no se queda cargando)',
    () async {
      final s = servicio(
        (_) => Completer<http.Response>().future,
        limite: const Duration(milliseconds: 20),
      );
      await expectLater(
        s.actualizar('t', nombre: 'Ana'),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
