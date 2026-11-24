import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';

/// Contrato de `ApiClient.delete`: lo comparten los favoritos y los tokens
/// de aviso, así que no depende de ninguno de los dos.
void main() {
  test('delete envía DELETE a la ruta con el token y sin cuerpo', () async {
    late http.Request recibida;
    final api = ApiClient(
      client: MockClient((peticion) async {
        recibida = peticion;
        return http.Response('', 204);
      }),
    );

    final respuesta = await api.delete('/favoritos/negocios/n1', token: 'tok');

    expect(respuesta.statusCode, 204);
    expect(recibida.method, 'DELETE');
    expect(
      recibida.url.toString(),
      '${ApiClient.baseUrl}/favoritos/negocios/n1',
    );
    expect(recibida.headers['Authorization'], 'Bearer tok');
    expect(recibida.headers['Accept'], 'application/json');
    expect(recibida.body, isEmpty);
  });

  test(
    'delete sin token no manda Authorization y manda el cuerpo si hay',
    () async {
      late http.Request recibida;
      final api = ApiClient(
        client: MockClient((peticion) async {
          recibida = peticion;
          return http.Response('', 204);
        }),
      );

      await api.delete('/x', body: '{"a":1}');

      expect(recibida.headers.containsKey('Authorization'), isFalse);
      expect(recibida.body, '{"a":1}');
    },
  );

  test('delete respeta el tiempo límite del cliente', () async {
    final api = ApiClient(
      limite: const Duration(milliseconds: 20),
      client: MockClient((_) => Completer<http.Response>().future),
    );

    await expectLater(
      api.delete('/x', token: 't'),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('put envía PUT con el token y sin cuerpo cuando no se da', () async {
    late http.Request recibida;
    final api = ApiClient(
      client: MockClient((peticion) async {
        recibida = peticion;
        return http.Response('', 204);
      }),
    );

    final respuesta = await api.put('/favoritos/negocios/n1', token: 'tok');

    expect(respuesta.statusCode, 204);
    expect(recibida.method, 'PUT');
    expect(
      recibida.url.toString(),
      '${ApiClient.baseUrl}/favoritos/negocios/n1',
    );
    expect(recibida.headers['Authorization'], 'Bearer tok');
    expect(recibida.body, isEmpty);
  });

  test('put manda el cuerpo cuando se da y respeta el tiempo límite', () async {
    late http.Request recibida;
    final api = ApiClient(
      limite: const Duration(milliseconds: 20),
      client: MockClient((peticion) async {
        recibida = peticion;
        if (peticion.url.path == '/lento') {
          return Completer<http.Response>().future;
        }
        return http.Response('', 204);
      }),
    );

    await api.put('/x', body: '{"a":1}');
    expect(recibida.body, '{"a":1}');
    await expectLater(api.put('/lento'), throwsA(isA<TimeoutException>()));
  });
}
