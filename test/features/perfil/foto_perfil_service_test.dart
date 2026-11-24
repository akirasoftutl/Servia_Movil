import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/perfil/data/foto_perfil.dart';
import 'package:servia/features/perfil/data/perfil_cliente.dart';
import 'package:servia/features/perfil/data/perfil_cliente_service.dart';
import 'package:servia/features/perfil/data/validacion_foto.dart';
import 'package:servia/features/perfil/mensajes.dart';

import 'fakes_perfil.dart';

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

void main() {
  group('PerfilCliente.foto (GET y PATCH /usuarios/yo, BE#115)', () {
    test('lee foto { id, url }', () {
      final perfil = PerfilCliente.fromJson({
        'nombre': 'Ana',
        'correo': 'a@a.com',
        'telefono': '4771234567',
        'foto': {'id': 'f1', 'url': 'https://supabase.test/f1.png'},
      });
      expect(perfil.foto?.id, 'f1');
      expect(perfil.foto?.url, 'https://supabase.test/f1.png');
    });

    test('foto null o ausente o malformada se lee como sin foto', () {
      for (final foto in [
        null,
        'x',
        {'id': 'f1'},
        {'url': 1},
      ]) {
        final perfil = PerfilCliente.fromJson({'nombre': 'Ana', 'foto': ?foto});
        expect(perfil.foto, isNull, reason: '$foto');
      }
      expect(PerfilCliente.fromJson({'nombre': 'Ana'}).foto, isNull);
    });

    test('conFoto cambia solo la foto', () {
      const base = PerfilCliente(
        nombre: 'Ana',
        correo: 'a@a.com',
        telefono: '1',
        foto: FotoPerfil(id: 'f1', url: 'u'),
      );
      final sin = base.conFoto(null);
      expect(sin.foto, isNull);
      expect(sin.nombre, 'Ana');
      expect(sin.correo, 'a@a.com');
    });
  });

  group('ValidacionFoto (antes de subir; la API decide al final)', () {
    Uint8List relleno(List<int> firma, [int total = 64]) {
      final bytes = Uint8List(total);
      bytes.setAll(0, firma);
      return bytes;
    }

    final jpeg = relleno([0xFF, 0xD8, 0xFF, 0xE0]);
    final webp = relleno([
      ...'RIFF'.codeUnits,
      0,
      0,
      0,
      0,
      ...'WEBP'.codeUnits,
    ]);

    test('acepta JPEG, PNG y WebP por su firma', () {
      expect(ValidacionFoto.validar(jpeg), isNull);
      expect(ValidacionFoto.validar(png1x1), isNull);
      expect(ValidacionFoto.validar(webp), isNull);
    });

    test('la extensión sale de la firma, no del nombre', () {
      expect(ValidacionFoto.extension(jpeg), 'jpg');
      expect(ValidacionFoto.extension(png1x1), 'png');
      expect(ValidacionFoto.extension(webp), 'webp');
    });

    test('rechaza otro formato o un archivo vacío', () {
      final gif = relleno('GIF89a'.codeUnits);
      expect(ValidacionFoto.validar(gif), MensajesPerfil.fotoFormato);
      expect(ValidacionFoto.validar(Uint8List(0)), MensajesPerfil.fotoFormato);
      expect(ValidacionFoto.extension(gif), isNull);
    });

    test('5 MB exactos pasan; un byte más se rechaza por tamaño', () {
      final justo = relleno([0xFF, 0xD8, 0xFF], ValidacionFoto.maxBytes);
      final pasado = relleno([0xFF, 0xD8, 0xFF], ValidacionFoto.maxBytes + 1);
      expect(ValidacionFoto.maxBytes, 5 * 1024 * 1024);
      expect(ValidacionFoto.validar(justo), isNull);
      expect(ValidacionFoto.validar(pasado), MensajesPerfil.fotoGrande);
    });
  });

  group('subirFoto: POST /usuarios/yo/foto multipart (campo archivo)', () {
    test(
      'manda Bearer, multipart con el campo archivo y devuelve { id, url }',
      () async {
        late http.Request visto;
        final s = servicio((r) async {
          visto = r;
          return json(201, {'id': 'f1', 'url': 'https://supabase.test/f1.png'});
        });
        final foto = await s.subirFoto('tok', png1x1, 'mi foto.png');
        expect(visto.method, 'POST');
        expect(visto.url.path, '/usuarios/yo/foto');
        expect(visto.headers['Authorization'], 'Bearer tok');
        expect(
          visto.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );
        final cuerpo = latin1.decode(visto.bodyBytes);
        expect(cuerpo, contains('name="archivo"'));
        expect(cuerpo, contains('filename="mi foto.png"'));
        // Un solo campo: no hay otras partes.
        expect(RegExp('content-disposition').allMatches(cuerpo), hasLength(1));
        expect(
          latin1.decode(png1x1.sublist(1, 4)),
          'PNG',
          reason: 'los bytes de la foto viajan tal cual',
        );
        expect(cuerpo, contains('PNG'));
        expect(foto.id, 'f1');
        expect(foto.url, 'https://supabase.test/f1.png');
      },
    );

    test('400 con el mensaje de la API lo conserva', () async {
      final s = servicio(
        (_) async => json(
          400,
          error(
            400,
            'El archivo debe ser una imagen JPEG, PNG o WebP válida.',
            'Bad Request',
          ),
        ),
      );
      final e = await fallo(() => s.subirFoto('tok', png1x1, 'a.png'));
      expect(e.statusCode, 400);
      expect(
        e.mensaje,
        'El archivo debe ser una imagen JPEG, PNG o WebP válida.',
      );
    });

    test('400 «Falta el archivo» se conserva tal cual', () async {
      final s = servicio(
        (_) async => json(
          400,
          error(
            400,
            'Falta el archivo de la foto (campo "archivo").',
            'Bad Request',
          ),
        ),
      );
      final e = await fallo(() => s.subirFoto('tok', png1x1, 'a.png'));
      expect(e.mensaje, 'Falta el archivo de la foto (campo "archivo").');
    });

    test('413 muestra el mensaje de tamaño', () async {
      final s = servicio(
        (_) async => json(
          413,
          error(
            413,
            'La foto supera el tamaño máximo de 5 MB.',
            'Payload Too Large',
          ),
        ),
      );
      final e = await fallo(() => s.subirFoto('tok', png1x1, 'a.png'));
      expect(e.statusCode, 413);
      expect(e.mensaje, MensajesPerfil.fotoGrande);
    });

    test('413 sin cuerpo de la API usa el mensaje de la app', () async {
      final s = servicio((_) async => http.Response('', 413));
      final e = await fallo(() => s.subirFoto('tok', png1x1, 'a.png'));
      expect(e.mensaje, MensajesPerfil.fotoGrande);
    });

    test(
      '503 de Supabase: mensaje de la API; sin cuerpo, uno de la app',
      () async {
        final con = servicio(
          (_) async => json(
            503,
            error(
              503,
              'No se pudo guardar la foto en Supabase Storage.',
              'Service Unavailable',
            ),
          ),
        );
        final e1 = await fallo(() => con.subirFoto('tok', png1x1, 'a.png'));
        expect(e1.statusCode, 503);
        expect(e1.mensaje, 'No se pudo guardar la foto en Supabase Storage.');
        final sin = servicio((_) async => http.Response('', 503));
        final e2 = await fallo(() => sin.subirFoto('tok', png1x1, 'a.png'));
        expect(e2.mensaje, MensajesPerfil.fotoNoGuardada);
      },
    );

    test('401, 403 y 404 con mensajes del módulo', () async {
      final esperados = {
        401: MensajesPerfil.sesionInvalida,
        403: MensajesPerfil.cuentaDesactivada,
        404: MensajesPerfil.sinPerfil,
      };
      for (final MapEntry(key: codigo, value: mensaje) in esperados.entries) {
        final s = servicio(
          (_) async => json(codigo, error(codigo, 'x', 'Error')),
        );
        final e = await fallo(() => s.subirFoto('tok', png1x1, 'a.png'));
        expect(e.statusCode, codigo);
        expect(e.mensaje, mensaje, reason: '$codigo');
      }
    });
  });

  group('quitarFoto: DELETE /usuarios/yo/foto', () {
    test('204 sin cuerpo: manda Bearer', () async {
      late http.Request visto;
      final s = servicio((r) async {
        visto = r;
        return http.Response('', 204);
      });
      await s.quitarFoto('tok');
      expect(visto.method, 'DELETE');
      expect(visto.url.path, '/usuarios/yo/foto');
      expect(visto.headers['Authorization'], 'Bearer tok');
    });

    test('503 con el mensaje de la API', () async {
      final s = servicio(
        (_) async => json(
          503,
          error(
            503,
            'Supabase Storage no está configurado en el servidor.',
            'Service Unavailable',
          ),
        ),
      );
      final e = await fallo(() => s.quitarFoto('tok'));
      expect(e.statusCode, 503);
      expect(e.mensaje, 'Supabase Storage no está configurado en el servidor.');
    });

    test('401 y 403', () async {
      for (final codigo in [401, 403]) {
        final s = servicio(
          (_) async => json(codigo, error(codigo, 'x', 'Error')),
        );
        final e = await fallo(() => s.quitarFoto('tok'));
        expect(e.statusCode, codigo);
      }
    });
  });
}
