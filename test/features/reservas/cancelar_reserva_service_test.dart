import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/reservas/data/reservas_service.dart';
import 'package:servia/features/reservas/mensajes.dart';

void main() {
  test('52 C4 un 409 sin mensaje válido conserva un error claro', () async {
    for (final cuerpo in ['{}', 'no es JSON', '{"message": []}']) {
      final reservas = ReservasService(
        api: ApiClient(
          client: MockClient((_) async => http.Response(cuerpo, 409)),
        ),
      );
      await expectLater(
        reservas.cancelar('token', 'r1'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'código', 409)
              .having(
                (e) => e.mensaje,
                'mensaje',
                MensajesReservas.errorCancelacion,
              ),
        ),
      );
    }
  });

  test(
    '52 C4 el envío de cancelación conserva el tiempo límite de ApiClient',
    () async {
      final reservas = ReservasService(
        api: ApiClient(
          limite: const Duration(milliseconds: 10),
          client: MockClient((_) => Completer<http.Response>().future),
        ),
      );
      await expectLater(
        reservas.cancelar('token', 'r1'),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}
