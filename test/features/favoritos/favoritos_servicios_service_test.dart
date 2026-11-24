import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/favoritos/data/favoritos_service.dart';

import 'fakes_favoritos.dart';

/// Contrato de `/favoritos/servicios` (Servia_BE#122, HU-C84, T18).
void main() {
  late ApiFavoritosFalsa api;
  late FavoritosService servicio;

  setUp(() {
    api = ApiFavoritosFalsa();
    servicio = api.servicio;
  });

  group('listarServicios', () {
    test('GET /favoritos/servicios con el token y lee {items}', () async {
      api.serviciosDe('ana').addAll([
        servicioFavorito(
          'n2',
          's9',
          nombre: 'Corte clásico',
          precio: 150.5,
          duracionMin: 45,
          negocioNombre: 'Barbería Luna',
        ),
        servicioFavorito('n1', 's1', precio: 200, aceptaReservas: false),
      ]);

      final lista = await servicio.listarServicios('token-ana');

      expect(api.metodos(), ['GET /favoritos/servicios']);
      expect(
        api.peticiones.single.headers['Authorization'],
        'Bearer token-ana',
      );
      expect(lista.map((s) => s.servicioId), ['s9', 's1']);
      final primero = lista.first;
      expect(primero.nombre, 'Corte clásico');
      expect(primero.precio, 150.5);
      expect(primero.duracionMin, 45);
      expect(primero.negocioId, 'n2');
      expect(primero.negocioNombre, 'Barbería Luna');
      expect(primero.aceptaReservas, isTrue);
      expect(lista.last.precio, 200);
      expect(lista.last.aceptaReservas, isFalse);
    });

    test('una cuenta sin favoritos devuelve la lista vacía', () async {
      expect(await servicio.listarServicios('token-ana'), isEmpty);
    });

    test('un cuerpo que no es el contrato falla con FormatException', () async {
      api.erroresServicios['GET'] = (codigo: 200, mensaje: null);
      await expectLater(
        servicio.listarServicios('token-ana'),
        throwsFormatException,
      );
    });

    test('un servicio sin precio numérico no es el contrato', () async {
      api.serviciosDe('ana').add({
        ...servicioFavorito('n1', 's1'),
        'precio': '150',
      });
      await expectLater(
        servicio.listarServicios('token-ana'),
        throwsFormatException,
      );
    });

    for (final codigo in [401, 403, 500]) {
      test('el $codigo llega como ApiException con ese código', () async {
        api.erroresServicios['GET'] = (codigo: codigo, mensaje: 'Algo');
        await expectLater(
          servicio.listarServicios('token-ana'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'código', codigo),
          ),
        );
      });
    }
  });

  group('agregarServicio', () {
    test(
      'PUT /favoritos/servicios/{negocioId}/{servicioId} sin cuerpo',
      () async {
        await servicio.agregarServicio('token-ana', 'n1', 's1');

        expect(api.metodos(), ['PUT /favoritos/servicios/n1/s1']);
        final peticion = api.peticiones.single;
        expect(peticion.bodyBytes, isEmpty);
        expect(peticion.headers.containsKey('Content-Type'), isFalse);
        expect(peticion.headers['Authorization'], 'Bearer token-ana');
        expect(api.serviciosDe('ana').map((s) => s['servicioId']), ['s1']);
      },
    );

    test('es idempotente: repetirlo no duplica', () async {
      await servicio.agregarServicio('token-ana', 'n1', 's1');
      await servicio.agregarServicio('token-ana', 'n1', 's1');
      expect(api.serviciosDe('ana'), hasLength(1));
    });

    test('404: conserva el mensaje de la API', () async {
      api.serviciosNoDisponibles.add('n1/s1');
      await expectLater(
        servicio.agregarServicio('token-ana', 'n1', 's1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'código', 404)
              .having(
                (e) => e.mensaje,
                'mensaje',
                'Servicio no encontrado o no está disponible.',
              ),
        ),
      );
    });

    test('409: conserva el mensaje del tope de 100', () async {
      api.topeServicios = 100;
      for (var i = 0; i < 100; i++) {
        api.serviciosDe('ana').add(servicioFavorito('n1', 'x$i'));
      }
      await expectLater(
        servicio.agregarServicio('token-ana', 'n1', 's1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'código', 409)
              .having(
                (e) => e.mensaje,
                'mensaje',
                'Llegaste al máximo de 100 servicios favoritos. Quita alguno para agregar otro.',
              ),
        ),
      );
    });

    test('un id con caracteres de ruta no sale a la red', () async {
      await expectLater(
        servicio.agregarServicio('token-ana', 'n1', '../s1'),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        servicio.agregarServicio('token-ana', 'a/b', 's1'),
        throwsA(isA<ApiException>()),
      );
      expect(api.peticiones, isEmpty);
    });
  });

  group('quitarServicio', () {
    test('DELETE /favoritos/servicios/{negocioId}/{servicioId}', () async {
      api.serviciosDe('ana')
        ..add(servicioFavorito('n1', 's2'))
        ..add(servicioFavorito('n1', 's1'));

      await servicio.quitarServicio('token-ana', 'n1', 's1');

      expect(api.metodos(), ['DELETE /favoritos/servicios/n1/s1']);
      expect(api.serviciosDe('ana').map((s) => s['servicioId']), ['s2']);
    });

    test('responde 204 aunque no fuera favorito', () async {
      await servicio.quitarServicio('token-ana', 'n1', 'nunca');
      expect(api.metodos(), ['DELETE /favoritos/servicios/n1/nunca']);
    });

    test('un 500 llega como ApiException', () async {
      api.erroresServicios['DELETE'] = (codigo: 500, mensaje: 'Falló');
      await expectLater(
        servicio.quitarServicio('token-ana', 'n1', 's1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'código', 500)),
      );
    });
  });
}
