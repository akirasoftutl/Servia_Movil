import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/theme/tema_servia.dart';
import 'package:servia/features/reservas/data/reservas_service.dart';
import 'package:servia/features/reservas/mensajes.dart';
import 'package:servia/features/reservas/pages/detalle_reserva_page.dart';

import 'datos_detalle.dart';
import 'fakes.dart';

class Escenario {
  Escenario({
    String estado = 'pendiente',
    bool cancelable = true,
    this.codigo = 200,
    this.espera,
    this.sinRed = false,
    this.inicio = '2026-11-10T05:30:00Z',
  }) : datos = {...datosDetalle, 'estado': estado, 'cancelable': cancelable};
  Map<String, dynamic> datos;
  int codigo;
  final Completer<void>? espera;
  final bool sinRed;
  final String inicio;
  int lecturas = 0;
  int envios = 0;
  final sesion = SesionFalsa();
  final solicitudes = <http.Request>[];

  Future<void> abrir(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(sesion.eventos.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: temaServia(),
        home: DetalleReservaPage(
          id: 'r1',
          authService: sesion,
          ahora: () => DateTime.utc(2026, 11, 1),
          reservasService: ReservasService(
            api: ApiClient(
              client: MockClient((r) async {
                solicitudes.add(r);
                expect(r.headers['Authorization'], 'Bearer token');
                if (r.method == 'GET') {
                  lecturas++;
                  expect(r.url.path, '/reservas/mias/r1');
                  return http.Response(
                    jsonEncode({...datos, 'inicio': inicio}),
                    200,
                  );
                }
                envios++;
                expect(r.method, 'PATCH');
                expect(r.url.path, '/reservas/mias/r1/cancelar');
                expect(r.body, isEmpty);
                if (espera != null) await espera!.future;
                if (sinRed) throw Exception('Sin conexión');
                if (codigo == 200 || codigo == 409) {
                  datos = {
                    ...datos,
                    'estado': 'cancelada',
                    'cancelable': false,
                  };
                }
                return http.Response(
                  jsonEncode({'message': 'La reserva ya fue cancelada.'}),
                  codigo,
                );
              }),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> confirmar(WidgetTester tester, String accion) async {
  await tester.tap(find.text(accion));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sí, cancelar'));
  await tester.pump();
}

void main() {
  testWidgets('52 C1 retira una Pendiente con el permiso de la API', (
    tester,
  ) async {
    final e = Escenario();
    await e.abrir(tester);
    expect(find.text('Retirar solicitud'), findsOneWidget);
    await confirmar(tester, 'Retirar solicitud');
    await tester.pumpAndSettle();
    expect(e.envios, 1);
    expect(e.lecturas, 2);
    expect(find.text('Cancelada'), findsOneWidget);
  });

  testWidgets('52 C1 Pendiente no cancelable no permite retirar', (
    tester,
  ) async {
    final e = Escenario(cancelable: false);
    await e.abrir(tester);
    expect(find.text('Retirar solicitud'), findsNothing);
    expect(find.text(MensajesReservas.limiteCancelacion), findsNothing);
    expect(e.envios, 0);
  });
  testWidgets('52 C2 Confirmada cancelable permite cancelar según la API', (
    tester,
  ) async {
    final e = Escenario(estado: 'confirmada');
    await e.abrir(tester);
    expect(find.text('Cancelar reserva'), findsOneWidget);
    expect(find.text('Retirar solicitud'), findsNothing);
    await confirmar(tester, 'Cancelar reserva');
    await tester.pumpAndSettle();
    expect(e.envios, 1);
    expect(find.text('Cancelada'), findsOneWidget);
  });

  testWidgets('52 C2 Confirmada fuera del límite explica sin botón', (
    tester,
  ) async {
    final e = Escenario(estado: 'confirmada', cancelable: false);
    await e.abrir(tester);
    expect(find.text('Cancelar reserva'), findsNothing);
    expect(find.text(MensajesReservas.limiteCancelacion), findsOneWidget);
    expect(e.envios, 0);
  });

  testWidgets(
    '52 C2 cita pasada sin permiso no muestra explicación ni acción',
    (tester) async {
      final e = Escenario(
        estado: 'confirmada',
        cancelable: false,
        inicio: '2026-10-31T23:59:00Z',
      );
      await e.abrir(tester);
      expect(find.text('Cancelar reserva'), findsNothing);
      expect(find.text(MensajesReservas.limiteCancelacion), findsNothing);
    },
  );
}
