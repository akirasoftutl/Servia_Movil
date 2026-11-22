import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/theme/tema_servia.dart';
import 'package:servia/features/reservas/data/reservas_service.dart';
import 'package:servia/features/reservas/pages/detalle_reserva_page.dart';
import 'package:servia/features/reservas/pages/mis_reservas_page.dart';
import 'package:servia/features/reservas/rutas_reservas.dart';
import 'package:servia/main.dart';

import 'datos_detalle.dart';
import 'fakes.dart';

void main() {
  testWidgets('D4 tarjeta abre /reservas/r1 y consulta el detalle por id', (
    tester,
  ) async {
    final consultas = <String>[];
    final rutas = <String?>[];
    final sesion = SesionFalsa();
    var ajena = false;
    final servicio = ReservasService(
      api: ApiClient(
        client: MockClient((r) async {
          consultas.add(r.url.path);
          expect(r.headers['Authorization'], 'Bearer token');
          if (r.url.path == '/reservas/mias') {
            return http.Response(
              jsonEncode({
                'items': [datosDetalle],
                'siguiente': null,
              }),
              200,
            );
          }
          return http.Response(jsonEncode(datosDetalle), ajena ? 404 : 200);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: temaServia(),
        home: MisReservasPage(authService: sesion, reservasService: servicio),
        onGenerateRoute: (ajustes) {
          rutas.add(ajustes.name);
          return generarRutaReservas(
            ajustes,
            authService: sesion,
            reservasService: servicio,
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barbería Central'));
    await tester.pumpAndSettle();
    expect(rutas, ['/reservas/r1']);
    expect(consultas, ['/reservas/mias', '/reservas/mias/r1']);
    expect(
      tester.widget<DetalleReservaPage>(find.byType(DetalleReservaPage)).id,
      'r1',
    );
    expect(find.text('SRV-7KQ2MX'), findsOneWidget);
    Navigator.of(tester.element(find.byType(DetalleReservaPage))).pop();
    await tester.pumpAndSettle();
    // La lista no entrega sus datos al detalle: un 404 posterior oculta el folio.
    ajena = true;
    await tester.tap(find.text('Barbería Central'));
    await tester.pumpAndSettle();
    expect(find.text('No encontramos esta reserva.'), findsOneWidget);
    expect(find.text('SRV-7KQ2MX'), findsNothing);
    await tester.tap(find.text('Volver a mis reservas'));
    await tester.pumpAndSettle();
    expect(find.byType(DetalleReservaPage), findsNothing);
    expect(find.text('Mis reservas'), findsOneWidget);
  });

  testWidgets('52 al volver del detalle tras cancelar ya no se ve Pendiente', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sesion = SesionFalsa();
    var datos = Map<String, dynamic>.of(datosDetalle);
    final servicio = ReservasService(
      api: ApiClient(
        client: MockClient((r) async {
          if (r.method == 'PATCH') {
            expect(r.url.path, '/reservas/mias/r1/cancelar');
            datos = {...datos, 'estado': 'cancelada', 'cancelable': false};
            return http.Response(jsonEncode(datos), 200);
          }
          if (r.url.path == '/reservas/mias') {
            return http.Response(
              jsonEncode({
                'items': [datos],
                'siguiente': null,
              }),
              200,
            );
          }
          return http.Response(jsonEncode(datos), 200);
        }),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: temaServia(),
        home: MisReservasPage(authService: sesion, reservasService: servicio),
        onGenerateRoute: (ajustes) => generarRutaReservas(
          ajustes,
          authService: sesion,
          reservasService: servicio,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pendiente'), findsOneWidget);
    await tester.tap(find.text('Barbería Central'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirar solicitud'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sí, cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelada'), findsOneWidget);
    Navigator.of(tester.element(find.byType(DetalleReservaPage))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(DetalleReservaPage), findsNothing);
    expect(find.text('Pendiente'), findsNothing);
    expect(find.text('Cancelada'), findsOneWidget);
  });

  testWidgets('D4 ServiaApp registra la ruta de reservas con solo el id', (
    tester,
  ) async {
    late BuildContext contexto;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          contexto = context;
          return const SizedBox();
        },
      ),
    );
    final app = const ServiaApp().build(contexto) as MaterialApp;
    const ajustes = RouteSettings(name: '/reservas/id-ajeno');
    final ruta = app.onGenerateRoute!(ajustes) as MaterialPageRoute;
    expect(ruta.settings, ajustes);
    final pagina = ruta.builder(contexto) as DetalleReservaPage;
    expect(pagina.id, 'id-ajeno');
    expect(pagina.authService, isNull);
    expect(pagina.reservasService, isNull);
  });
}
