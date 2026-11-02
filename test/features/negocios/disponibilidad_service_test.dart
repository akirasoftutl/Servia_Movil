import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/disponibilidad.dart';
import 'package:servia/features/negocios/data/disponibilidad_service.dart';

void main() {
  test('consulta pública respeta ruta y los dos DTO de Swagger', () async {
    final rutas = <Uri>[];
    final servicio = DisponibilidadService(
      api: ApiClient(
        client: MockClient((r) async {
          rutas.add(r.url);
          expect(r.headers.containsKey('Authorization'), isFalse);
          return http.Response(
            jsonEncode(
              r.url.queryParameters.isEmpty
                  ? [
                      {'fecha': '2026-11-02', 'disponible': false},
                    ]
                  : [
                      {'hora': '09:30', 'disponible': false},
                      {'hora': '10:00', 'disponible': true},
                    ],
            ),
            200,
          );
        }),
      ),
    );
    final dias = await servicio.obtenerDias('negocio', 'servicio');
    final horas = await servicio.obtenerHoras(
      'negocio',
      'servicio',
      '2026-11-02',
    );
    expect(dias.single.fecha, '2026-11-02');
    expect(dias.single.disponible, isFalse);
    expect(horas.map((h) => h.hora), ['09:30', '10:00']);
    expect(horas.map((h) => h.disponible), [false, true]);
    expect(
      rutas.first.path,
      '/negocios/negocio/servicios/servicio/disponibilidad',
    );
    expect(rutas.first.query, isEmpty);
    expect(rutas.last.queryParameters, {'fecha': '2026-11-02'});
  });

  test('rechaza respuestas inválidas y propaga errores HTTP', () async {
    for (final caso in [
      (200, '{}'),
      (200, '[{"fecha":"2026-02-30","disponible":true}]'),
      (200, '[{"fecha":"2026-11-02","disponible":"true"}]'),
      (503, 'privado'),
    ]) {
      final servicio = DisponibilidadService(
        api: ApiClient(
          client: MockClient((_) async => http.Response(caso.$2, caso.$1)),
        ),
      );
      await expectLater(
        servicio.obtenerDias('n', 's'),
        throwsA(caso.$1 == 200 ? isA<FormatException>() : isA<ApiException>()),
      );
    }
    expect(
      () => HoraDisponibilidad.fromJson({'hora': '24:00', 'disponible': true}),
      throwsFormatException,
    );
  });

  test('consulta utiliza el tiempo límite del ApiClient', () async {
    final pendiente = Completer<http.Response>();
    final servicio = DisponibilidadService(
      api: ApiClient(
        limite: const Duration(milliseconds: 5),
        client: MockClient((_) => pendiente.future),
      ),
    );
    await expectLater(
      servicio.obtenerDias('n', 's'),
      throwsA(isA<TimeoutException>()),
    );
    pendiente.complete(http.Response('[]', 200));
  });

  test(
    'inicio se interpreta en México aunque el instante UTC cambie de día',
    () {
      const hora = HoraDisponibilidad(hora: '23:30', disponible: true);
      expect(
        hora.inicio('2026-11-02').toUtc(),
        DateTime.utc(2026, 11, 3, 5, 30),
      );
    },
  );
}
