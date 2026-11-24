import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/favoritos/data/favoritos_service.dart';

import 'fakes_favoritos.dart';

void main() {
  late ApiFavoritosFalsa api;
  late FavoritosService servicio;

  setUp(() {
    api = ApiFavoritosFalsa();
    servicio = api.servicio;
  });

  group('listar', () {
    test(
      'GET /favoritos/negocios con el token y lee {items} del contrato',
      () async {
        api.de('ana').addAll([
          negocioFavorito(
            'b2',
            nombre: 'Barbería Luna',
            portadaUrl: 'https://img/b2.jpg',
          ),
          negocioFavorito('b1', aceptaReservas: false),
        ]);

        final lista = await servicio.listar('token-ana');

        expect(api.metodos(), ['GET /favoritos/negocios']);
        expect(
          api.peticiones.single.headers['Authorization'],
          'Bearer token-ana',
        );
        expect(lista.map((n) => n.id), ['b2', 'b1']);
        expect(lista.first.nombre, 'Barbería Luna');
        expect(lista.first.categoriaId, 'cabello');
        expect(lista.first.imagenUrl, 'https://img/b2.jpg');
        expect(lista.last.aceptaReservas, isFalse);
        expect(lista.last.imagenUrl, isNull);
      },
    );

    test('una cuenta sin favoritos devuelve la lista vacía', () async {
      expect(await servicio.listar('token-ana'), isEmpty);
    });

    test('un cuerpo que no es el contrato falla con FormatException', () async {
      api.errores['GET'] = (codigo: 200, mensaje: null);
      await expectLater(servicio.listar('token-ana'), throwsFormatException);
    });

    for (final codigo in [401, 403, 500]) {
      test('el $codigo llega como ApiException con ese código', () async {
        api.errores['GET'] = (codigo: codigo, mensaje: 'Algo');
        await expectLater(
          servicio.listar('token-ana'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'código', codigo),
          ),
        );
      });
    }
  });

  group('agregar', () {
    test('PUT /favoritos/negocios/{id} sin cuerpo con el token', () async {
      await servicio.agregar('token-ana', 'b1');

      final peticion = api.peticiones.single;
      expect(peticion.method, 'PUT');
      expect(peticion.url.path, '/favoritos/negocios/b1');
      expect(peticion.headers['Authorization'], 'Bearer token-ana');
      expect(peticion.body, isEmpty);
      expect(api.de('ana').map((n) => n['id']), ['b1']);
    });

    test('es idempotente: repetirlo no falla ni duplica', () async {
      await servicio.agregar('token-ana', 'b1');
      await servicio.agregar('token-ana', 'b1');
      expect(api.de('ana'), hasLength(1));
    });

    test('404 conserva el mensaje de la API en la excepción', () async {
      api.noDisponibles.add('b9');
      await expectLater(
        servicio.agregar('token-ana', 'b9'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'código', 404)
              .having(
                (e) => e.mensaje,
                'mensaje',
                'Negocio no encontrado o no está disponible.',
              ),
        ),
      );
    });

    test('409 trae el mensaje de la API del tope de 100', () async {
      api.tope = 1;
      await servicio.agregar('token-ana', 'b1');
      await expectLater(
        servicio.agregar('token-ana', 'b2'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'código', 409)
              .having(
                (e) => e.mensaje,
                'mensaje',
                'Llegaste al máximo de 1 favoritos. Quita alguno para agregar otro.',
              ),
        ),
      );
    });

    test(
      'un id con caracteres de ruta no sale de /favoritos/negocios',
      () async {
        await expectLater(
          servicio.agregar('token-ana', '../usuarios'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'código', 404),
          ),
        );
        expect(api.peticiones, isEmpty);
      },
    );

    test('un cuerpo de error que no es JSON usa el mensaje genérico', () async {
      api.errores['PUT'] = (codigo: 500, mensaje: null);
      await expectLater(
        servicio.agregar('token-ana', 'b1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'código', 500)),
      );
    });
  });

  group('quitar', () {
    test('DELETE /favoritos/negocios/{id} con el token', () async {
      api.de('ana').add(negocioFavorito('b1'));

      await servicio.quitar('token-ana', 'b1');

      final peticion = api.peticiones.single;
      expect(peticion.method, 'DELETE');
      expect(peticion.url.path, '/favoritos/negocios/b1');
      expect(peticion.headers['Authorization'], 'Bearer token-ana');
      expect(api.de('ana'), isEmpty);
    });

    test('quitar uno que no era favorito responde 204 y no falla', () async {
      await servicio.quitar('token-ana', 'nunca');
    });

    test('401 llega como ApiException', () async {
      await expectLater(
        servicio.quitar('sin-formato', 'b1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'código', 401)),
      );
    });
  });
}
