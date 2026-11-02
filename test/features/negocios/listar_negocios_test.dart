import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';

Map<String, dynamic> resumenJson() => {
  'id': 'n1',
  'nombre': 'Negocio',
  'categoriaId': 'cabello',
  'aceptaReservas': false,
};

void main() {
  test('consulta pública con límite y cursor codificado', () async {
    final service = NegociosService(
      api: ApiClient(
        client: MockClient((r) async {
          expect(r.method, 'GET');
          expect(r.url.path, '/negocios');
          expect(r.url.queryParameters, {'limite': '20', 'cursor': 'á +/=?'});
          expect(r.headers.containsKey('Authorization'), false);
          return http.Response(
            jsonEncode({
              'items': [resumenJson()],
              'siguiente': 'dos',
            }),
            200,
          );
        }),
      ),
    );
    final pagina = await service.listarNegocios(cursor: 'á +/=?');
    expect(pagina.items.single.aceptaReservas, false);
    expect(pagina.siguiente, 'dos');
  });
  test('primera consulta sin cursor', () async {
    final service = NegociosService(
      api: ApiClient(
        client: MockClient((r) async {
          expect(r.url.queryParameters, {'limite': '20'});
          return http.Response('{"items":[],"siguiente":null}', 200);
        }),
      ),
    );
    expect((await service.listarNegocios()).items, isEmpty);
  });
  for (final estado in [400, 500]) {
    test('rechaza respuesta $estado', () async {
      final service = NegociosService(
        api: ApiClient(
          client: MockClient(
            (_) async => http.Response('{"message":"dato crudo"}', estado),
          ),
        ),
      );
      await expectLater(
        service.listarNegocios(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'estado', estado),
        ),
      );
    });
  }
  test('rechaza páginas e items mal formados', () {
    for (final datos in <Map<String, dynamic>>[
      {},
      {'items': [], 'siguiente': 2},
      {
        'items': [null],
        'siguiente': null,
      },
      for (final campo in resumenJson().keys)
        {
          'items': [
            {...resumenJson(), campo: 2},
          ],
          'siguiente': null,
        },
      {
        'items': [
          {...resumenJson(), 'id': 'a/b'},
        ],
        'siguiente': null,
      },
    ]) {
      expect(() => PaginaNegocios.fromJson(datos), throwsFormatException);
    }
  });
  test('rechaza json inesperado desde el servicio', () async {
    final service = NegociosService(
      api: ApiClient(client: MockClient((_) async => http.Response('[]', 200))),
    );
    await expectLater(service.listarNegocios(), throwsFormatException);
  });
}
