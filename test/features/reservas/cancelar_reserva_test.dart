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
  testWidgets('52 C3 exige las tres condiciones y No volver no envía', (
    tester,
  ) async {
    final e = Escenario();
    await e.abrir(tester);
    await tester.tap(find.text('Retirar solicitud'));
    await tester.pumpAndSettle();
    expect(find.text('Condiciones de cancelación'), findsOneWidget);
    expect(
      find.text(
        'Puedes retirar una solicitud pendiente en cualquier momento antes de la cita.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Una reserva confirmada solo se puede cancelar hasta 24 horas antes de la cita.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Una vez cancelada, la reserva no se puede reactivar. Si después quieres el servicio, haz una nueva reserva.',
      ),
      findsOneWidget,
    );
    expect(e.envios, 0);
    await tester.tap(find.text('No, volver'));
    await tester.pumpAndSettle();
    expect(e.envios, 0);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await confirmar(tester, 'Retirar solicitud');
    await tester.pumpAndSettle();
    expect(e.envios, 1);
  });

  testWidgets('52 C3 cerrar el diálogo tampoco envía', (tester) async {
    final e = Escenario();
    await e.abrir(tester);
    await tester.tap(find.text('Retirar solicitud'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(AlertDialog))).pop();
    await tester.pumpAndSettle();
    expect(e.envios, 0);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('cancelar-reserva')))
          .onPressed,
      isNotNull,
    );
  });
  testWidgets('52 C4 éxito avisa y recarga el estado desde la API', (
    tester,
  ) async {
    final e = Escenario(estado: 'confirmada');
    await e.abrir(tester);
    await confirmar(tester, 'Cancelar reserva');
    await tester.pumpAndSettle();
    expect(
      find.text('Tu reserva fue cancelada. El horario quedó libre.'),
      findsOneWidget,
    );
    expect(e.solicitudes.map((r) => r.method), ['GET', 'PATCH', 'GET']);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.byKey(const ValueKey('cancelar-reserva')), findsNothing);
  });

  testWidgets('52 C4 409 muestra el mensaje de la API y recarga', (
    tester,
  ) async {
    final e = Escenario(codigo: 409);
    await e.abrir(tester);
    await confirmar(tester, 'Retirar solicitud');
    await tester.pumpAndSettle();
    expect(find.text('La reserva ya fue cancelada.'), findsOneWidget);
    expect(e.lecturas, 2);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(
      find.text('Tu reserva fue cancelada. El horario quedó libre.'),
      findsNothing,
    );
  });

  for (final codigo in [401, 404]) {
    testWidgets('52 C4 error $codigo da el mensaje claro sin anunciar éxito', (
      tester,
    ) async {
      final e = Escenario(codigo: codigo);
      await e.abrir(tester);
      await confirmar(tester, 'Retirar solicitud');
      await tester.pumpAndSettle();
      expect(
        find.text(
          codigo == 401
              ? 'Tu sesión ya no es válida. Inicia sesión de nuevo.'
              : 'Esta reserva ya no está disponible.',
        ),
        findsOneWidget,
      );
      expect(e.lecturas, 1);
      expect(
        find.text('Tu reserva fue cancelada. El horario quedó libre.'),
        findsNothing,
      );
      expect(find.text('Pendiente'), findsOneWidget);
    });
  }

  testWidgets('52 C4 sin conexión conserva el estado e informa', (
    tester,
  ) async {
    final e = Escenario(sinRed: true);
    await e.abrir(tester);
    await confirmar(tester, 'Retirar solicitud');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Pendiente'), findsOneWidget);
    expect(e.envios, 1);
  });

  testWidgets('52 C4 durante el envío deshabilita y evita duplicados', (
    tester,
  ) async {
    final espera = Completer<void>();
    final e = Escenario(espera: espera);
    await e.abrir(tester);
    await confirmar(tester, 'Retirar solicitud');
    await tester.pump(const Duration(milliseconds: 500));
    final boton = find.byKey(const ValueKey('cancelar-reserva'));
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);
    await tester.tap(boton);
    await tester.pump();
    expect(e.envios, 1);
    espera.complete();
    await tester.pumpAndSettle();
    expect(e.envios, 1);
    expect(find.text('Cancelada'), findsOneWidget);
  });

  testWidgets('52 C4 sin sesión al confirmar no manda PATCH', (tester) async {
    final e = Escenario();
    await e.abrir(tester);
    e.sesion.usuario = null;
    await confirmar(tester, 'Retirar solicitud');
    await tester.pumpAndSettle();
    expect(e.envios, 0);
    expect(
      find.text('Tu sesión ya no es válida. Inicia sesión de nuevo.'),
      findsOneWidget,
    );
  });
}
