import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';

import 'datos_prueba.dart';

NegociosService servicioCon(
  Future<http.Response> Function(http.Request) responder,
) => NegociosService(api: ApiClient(client: MockClient(responder)));

void main() {
  group('consultas públicas', () {
    test('pide el perfil exacto sin authorization y lee el modelo', () async {
      final servicio = servicioCon((peticion) async {
        expect(peticion.method, 'GET');
        expect(peticion.url.toString(), '${ApiClient.baseUrl}/negocios/abc123');
        expect(peticion.headers.containsKey('Authorization'), isFalse);
        return http.Response(jsonEncode(negocioJson()), 200);
      });
      expect((await servicio.obtenerNegocio('abc123')).nombre, 'Salón Aurora');
    });
    test('pide categorías sin token', () async {
      final servicio = servicioCon((peticion) async {
        expect(peticion.url.path, '/categorias');
        expect(peticion.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          '[{"id":"cabello","nombre":"Cabello","orden":1,"activo":true}]',
          200,
        );
      });
      expect((await servicio.obtenerCategorias()).single.nombre, 'Cabello');
    });
    test('conserva los estados 404 y 500 sin exponer el cuerpo', () async {
      for (final estado in [404, 500]) {
        final servicio = servicioCon(
          (_) async => http.Response('dato privado', estado),
        );
        await expectLater(
          servicio.obtenerNegocio('abc123'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'estado', estado)
                .having(
                  (e) => e.mensaje,
                  'mensaje',
                  isNot(contains('dato privado')),
                ),
          ),
        );
        await expectLater(
          servicio.obtenerCategorias(),
          throwsA(isA<ApiException>()),
        );
      }
    });
    test('ids inválidos no hacen ninguna petición', () async {
      var peticiones = 0;
      final servicio = servicioCon((_) async {
        peticiones++;
        return http.Response('{}', 200);
      });
      for (final id in ['', 'a/b', 'a%2Fb', 'a?b', 'a b', 'á', 'a' * 129]) {
        await expectLater(
          servicio.obtenerNegocio(id),
          throwsA(isA<ApiException>()),
        );
      }
      expect(peticiones, 0);
      expect(esIdValido('a_B-12'), isTrue);
      expect(esIdValido('a' * 128), isTrue);
    });
    test('respuestas inesperadas producen excepción de formato', () async {
      for (final cuerpo in ['[]', 'null', 'false', 'no json', '{}']) {
        await expectLater(
          servicioCon((_) async => http.Response(cuerpo, 200))
              .obtenerNegocio('abc123'),
          throwsFormatException,
        );
      }
      await expectLater(
        servicioCon((_) async => http.Response('{}', 200)).obtenerCategorias(),
        throwsFormatException,
      );
    });
    testWidgets('las consultas tienen límite de diez segundos', (tester) async {
      final pendiente = Completer<http.Response>();
      final servicio = servicioCon((_) => pendiente.future);
      final resultado = expectLater(
        servicio.obtenerNegocio('abc123'),
        throwsA(isA<TimeoutException>()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await resultado;
      pendiente.complete(http.Response('{}', 200));
      await tester.pump();
    });
  });
}
