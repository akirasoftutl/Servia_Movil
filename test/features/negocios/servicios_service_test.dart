import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/data/servicio.dart';
import 'package:servia/features/negocios/formatos.dart';

Map<String, dynamic> servicioJson({String id = 's2', num precio = 150}) => {
  'id': id,
  'nombre': 'Corte $id',
  'precio': precio,
  'duracionMin': 90,
};
NegociosService crearServicio(
  Future<http.Response> Function(http.Request) responder,
) => NegociosService(api: ApiClient(client: MockClient(responder)));

void main() {
  group('servicios públicos', () {
    test('lee precio entero y decimal y descripción defensivamente', () {
      for (final precio in [150, 150.5]) {
        final servicio = Servicio.fromJson(servicioJson(precio: precio));
        expect(servicio.id, 's2');
        expect(servicio.nombre, 'Corte s2');
        expect(servicio.precio, precio);
        expect(servicio.duracionMin, 90);
        expect(servicio.descripcion, isNull);
      }
      expect(
        Servicio.fromJson({
          ...servicioJson(),
          'descripcion': 'Corte con lavado',
        }, requiereDescripcion: true).descripcion,
        'Corte con lavado',
      );
      expect(
        Servicio.fromJson({...servicioJson(), 'descripcion': ''}).descripcion,
        isNull,
      );
      for (final campo in servicioJson().keys) {
        expect(
          () => Servicio.fromJson({...servicioJson(), campo: null}),
          throwsFormatException,
        );
        expect(
          () => Servicio.fromJson({
            ...servicioJson(),
            campo: campo == 'precio' ? '150' : false,
          }),
          throwsFormatException,
        );
      }
      expect(
        () => Servicio.fromJson(servicioJson(), requiereDescripcion: true),
        throwsFormatException,
      );
      expect(
        () => Servicio.fromJson({...servicioJson(), 'descripcion': 23}),
        throwsFormatException,
      );
      expect(
        () => Servicio.fromJson({...servicioJson(), 'duracionMin': 30.5}),
        throwsFormatException,
      );
    });
    test('lista exactamente lo que devuelve la API sin filtrar ni reordenar y sin token', () async {
      final servicio = crearServicio((peticion) async {
        expect(peticion.method, 'GET');
        expect(
          peticion.url.toString(),
          '${ApiClient.baseUrl}/negocios/abc123/servicios',
        );
        expect(peticion.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          jsonEncode([servicioJson(), servicioJson(id: 's1', precio: 150.5)]),
          200,
        );
      });
      final lista = await servicio.obtenerServicios('abc123');
      expect(lista.map((s) => s.id), ['s2', 's1']);
      expect(lista.map((s) => s.precio), [150, 150.5]);
      expect(
        await crearServicio((_) async => http.Response('[]', 200))
            .obtenerServicios('abc123'),
        isEmpty,
      );
    });
    test('pide el detalle exacto sin token y con descripción', () async {
      final servicio = crearServicio((peticion) async {
        expect(peticion.method, 'GET');
        expect(
          peticion.url.toString(),
          '${ApiClient.baseUrl}/negocios/abc123/servicios/s2',
        );
        expect(peticion.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          jsonEncode({...servicioJson(), 'descripcion': 'Corte con lavado'}),
          200,
        );
      });
      expect(
        (await servicio.obtenerServicio('abc123', 's2')).descripcion,
        'Corte con lavado',
      );
    });
    test('lista y detalle conservan 404 y 500 sin mostrar el cuerpo', () async {
      for (final estado in [404, 500]) {
        final servicio = crearServicio(
          (_) async => http.Response('privado', estado),
        );
        final error = throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'estado', estado)
              .having((e) => e.mensaje, 'mensaje', isNot(contains('privado'))),
        );
        await expectLater(servicio.obtenerServicios('abc123'), error);
        await expectLater(servicio.obtenerServicio('abc123', 's2'), error);
      }
    });
    test('ningún id inválido hace peticiones en lista ni detalle', () async {
      var peticiones = 0;
      final servicio = crearServicio((_) async {
        peticiones++;
        return http.Response('{}', 200);
      });
      for (final id in ['', 'a/b', 'a%2Fb', 'a?b', 'a b', 'á', 'a' * 129]) {
        await expectLater(
          servicio.obtenerServicios(id),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          servicio.obtenerServicio(id, 's2'),
          throwsA(isA<ApiException>()),
        );
        await expectLater(
          servicio.obtenerServicio('abc123', id),
          throwsA(isA<ApiException>()),
        );
      }
      expect(peticiones, 0);
    });
    test('rechaza estructuras malformadas sin cast errors', () async {
      for (final cuerpo in ['null', '{}', '[2]', '[{"id":false}]']) {
        await expectLater(
          crearServicio((_) async => http.Response(cuerpo, 200))
              .obtenerServicios('abc123'),
          throwsFormatException,
        );
      }
      for (final cuerpo in ['null', '[]', '{}', jsonEncode(servicioJson())]) {
        await expectLater(
          crearServicio((_) async => http.Response(cuerpo, 200))
              .obtenerServicio('abc123', 's2'),
          throwsFormatException,
        );
      }
    });
    testWidgets('catálogo lista y detalle vencen después de diez segundos', (
      tester,
    ) async {
      for (final consulta in [
        (NegociosService s) => s.obtenerCategorias(),
        (NegociosService s) => s.obtenerServicios('abc123'),
        (NegociosService s) => s.obtenerServicio('abc123', 's2'),
      ]) {
        final pendiente = Completer<http.Response>();
        final resultado = expectLater(
          consulta(crearServicio((_) => pendiente.future)),
          throwsA(isA<TimeoutException>()),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 10));
        await resultado;
        pendiente.complete(http.Response('{}', 200));
        await tester.pump();
      }
    });
  });
  test('formatea precios con dos decimales solo si hay centavos', () {
    for (final par in <num, String>{
      0: r'$0',
      150: r'$150',
      150.5: r'$150.50',
      99.99: r'$99.99',
    }.entries) {
      expect(formatearPrecio(par.key), par.value);
    }
  });
  test('formatea duración en horas y minutos', () {
    for (final par in {30: '30 min', 60: '1 h', 90: '1 h 30 min'}.entries) {
      expect(formatearDuracion(par.key), par.value);
    }
  });
}
