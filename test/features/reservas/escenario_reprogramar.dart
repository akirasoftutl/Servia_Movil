import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/theme/tema_servia.dart';
import 'package:servia/features/negocios/data/disponibilidad_service.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/reservas/data/reservas_service.dart';
import 'package:servia/features/reservas/pages/detalle_reserva_page.dart';

import 'fakes.dart';

/// Hora fija de las pruebas: 3/11/2026 10:15 de México (16:15 UTC).
final ahoraReprogramar = DateTime.utc(2026, 11, 3, 16, 15);

/// Cuerpos tal como los arma `Servia_BE` (BE#117, `src/reservas/dto/`):
/// `RespuestaDetalleReservaClienteDto` con `reprogramable`,
/// `reprogramableHasta` y `motivoNoReprogramable`.
Map<String, dynamic> detalleApi({
  String estado = 'pendiente',
  bool reprogramable = true,
  String? reprogramableHasta = '2026-11-10T16:00:00.000Z',
  String? motivoNoReprogramable,
  String inicio = '2026-11-10T16:00:00.000Z',
  String fin = '2026-11-10T17:00:00.000Z',
  String servicioId = 's1',
  String servicioNombre = 'Corte de cabello',
  num precio = 150,
  int duracionMin = 60,
}) => {
  'id': 'r1',
  'folio': 'SRV-7KQ2MX',
  'estado': estado,
  'inicio': inicio,
  'fin': fin,
  'servicio': {
    'id': servicioId,
    'nombre': servicioNombre,
    'precio': precio,
    'duracionMin': duracionMin,
  },
  'negocio': {
    'id': 'n1',
    'nombre': 'Barbería Central',
    'direccionTexto': 'Juárez 10, León, Guanajuato',
    'telefono': '4771234567',
  },
  'venceEn': '2026-11-10T14:00:00.000Z',
  'observaciones': null,
  'motivo': null,
  'cancelable': true,
  'cancelableHasta': '2026-11-10T16:00:00.000Z',
  'reprogramable': reprogramable,
  'reprogramableHasta': reprogramableHasta,
  'motivoNoReprogramable': motivoNoReprogramable,
};

/// Error de Nest: `{ message, error, statusCode }`.
String errorNest(int codigo, String mensaje, String nombre) =>
    jsonEncode({'message': mensaje, 'error': nombre, 'statusCode': codigo});

/// `GET /negocios/n1/servicios` (lista pública de servicios activos).
const serviciosApi = [
  {'id': 's1', 'nombre': 'Corte de cabello', 'precio': 150, 'duracionMin': 60},
  {
    'id': 's2',
    'nombre': 'Masaje relajante',
    'precio': 300.5,
    'duracionMin': 90,
  },
];

/// API simulada con las rutas reales: detalle, disponibilidad de la reserva,
/// servicios del negocio y `PATCH .../reprogramar`.
class EscenarioReprogramar {
  EscenarioReprogramar({Map<String, dynamic>? detalle})
    : detalle = detalle ?? detalleApi();

  Map<String, dynamic> detalle;
  int codigoPatch = 200;
  String? cuerpoPatch;
  Completer<void>? esperaPatch;
  bool sinRedPatch = false;
  int codigoDisponibilidad = 200;
  int codigoServicios = 200;

  final peticiones = <http.Request>[];
  final sesion = SesionFalsa();

  Iterable<http.Request> get lecturasDetalle => peticiones.where(
    (r) => r.method == 'GET' && r.url.path == '/reservas/mias/r1',
  );
  Iterable<http.Request> get envios =>
      peticiones.where((r) => r.method == 'PATCH');
  Iterable<http.Request> get consultasDisponibilidad => peticiones.where(
    (r) => r.url.path.endsWith('/disponibilidad'),
  );

  late final ApiClient api = ApiClient(
    client: MockClient((r) async {
      peticiones.add(r);
      final ruta = r.url.path;
      if (r.method == 'GET' && ruta == '/reservas/mias/r1') {
        return http.Response(jsonEncode(detalle), 200);
      }
      if (r.method == 'GET' && ruta == '/reservas/mias/r1/disponibilidad') {
        expect(r.headers['Authorization'], 'Bearer token');
        if (codigoDisponibilidad != 200) {
          return http.Response(
            errorNest(codigoDisponibilidad, 'No', 'Error'),
            codigoDisponibilidad,
          );
        }
        final fecha = r.url.queryParameters['fecha'];
        if (fecha == null) {
          return http.Response(
            jsonEncode([
              for (var d = 3; d <= 12; d++)
                {
                  'fecha': '2026-11-${'$d'.padLeft(2, '0')}',
                  'disponible': true,
                },
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {'hora': '09:30', 'disponible': true},
            // La propia cita no sale ocupada (BE: no cuenta la reserva).
            {'hora': '10:00', 'disponible': true},
            {'hora': '10:30', 'disponible': false},
          ]),
          200,
        );
      }
      if (r.method == 'GET' && ruta == '/negocios/n1/servicios') {
        if (codigoServicios != 200) {
          return http.Response('{}', codigoServicios);
        }
        return http.Response(jsonEncode(serviciosApi), 200);
      }
      if (r.method == 'PATCH' && ruta == '/reservas/mias/r1/reprogramar') {
        expect(r.headers['Authorization'], 'Bearer token');
        if (esperaPatch != null) await esperaPatch!.future;
        if (sinRedPatch) throw Exception('Sin conexión');
        return http.Response(cuerpoPatch ?? '{}', codigoPatch);
      }
      return http.Response('no esperada: ${r.method} $ruta', 500);
    }),
  );

  ReservasService get reservas => ReservasService(api: api);
  NegociosService get negocios => NegociosService(api: api);
  DisponibilidadService get disponibilidad => DisponibilidadService(api: api);

  /// Cuerpo de éxito (`RespuestaReprogramacionDto`).
  static String exito({
    String inicio = '2026-11-12T15:30:00.000Z',
    String fin = '2026-11-12T16:30:00.000Z',
    num precio = 150,
    int duracionMin = 60,
  }) => jsonEncode({
    'id': 'r1',
    'folio': 'SRV-7KQ2MX',
    'estado': 'pendiente',
    'inicio': inicio,
    'fin': fin,
    'precio': precio,
    'duracionMin': duracionMin,
    'venceEn': '2026-11-03T18:15:00.000Z',
    'reprogramadaEn': '2026-11-03T16:15:00.000Z',
  });

  Widget detallePage() => DetalleReservaPage(
    id: 'r1',
    authService: sesion,
    reservasService: reservas,
    negociosService: negocios,
    disponibilidadService: disponibilidad,
    ahora: () => ahoraReprogramar,
  );

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(sesion.eventos.close);
    await tester.pumpWidget(
      MaterialApp(theme: temaServia(), home: detallePage()),
    );
    await tester.pumpAndSettle();
  }

  /// Detalle → «Cambiar fecha u hora» → elegir día y hora → resumen.
  Future<void> hastaElResumen(
    WidgetTester tester, {
    String dia = '12',
    String hora = '09:30',
    String? servicio,
  }) async {
    await tester.tap(find.text('Cambiar fecha u hora'));
    await tester.pumpAndSettle();
    if (servicio != null) {
      await tester.tap(find.text('Cambiar de servicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(servicio));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Elegir nueva fecha y hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(dia));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('hora-$hora')));
    await tester.pumpAndSettle();
  }
}
