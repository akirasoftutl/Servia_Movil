import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/theme/tema_servia.dart';
import 'package:servia/core/widgets/etiqueta_estado.dart';
import 'package:servia/features/reservas/data/reservas_service.dart';
import 'package:servia/features/reservas/pages/detalle_reserva_page.dart';

import 'datos_detalle.dart';
import 'fakes.dart';

Future<void> abrir(
  WidgetTester tester, {
  Map<String, dynamic> datos = datosDetalle,
  int codigo = 200,
  SesionFalsa? sesion,
  Future<http.Response> Function(http.Request)? respuesta,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: temaServia(),
      home: DetalleReservaPage(
        id: 'r1',
        authService: sesion ?? SesionFalsa(),
        reservasService: ReservasService(
          api: ApiClient(
            client: MockClient(
              respuesta ??
                  (_) async => http.Response(jsonEncode(datos), codigo),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('C1 muestra la reserva completa y la fecha de México', (
    tester,
  ) async {
    await abrir(tester);
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('SRV-7KQ2MX'), findsOneWidget);
    expect(find.byType(EtiquetaEstado), findsOneWidget);
    for (final texto in [
      'Pendiente',
      'Fecha y hora',
      'lunes 9 de noviembre de 2026',
      '23:30',
      'Servicio',
      'Corte de cabello',
      '1 h 30 min',
      '\$150.50',
      'Negocio',
      'Barbería Central',
      'Juárez 10, León, Guanajuato',
      '4771234567',
      'Observaciones',
      'Corte con tijera.',
    ]) {
      expect(find.text(texto), findsOneWidget, reason: texto);
    }
    expect(find.text('Cancelar'), findsNothing);
    expect(find.text('Motivo del rechazo'), findsNothing);
    expect(find.text('Motivo de la cancelación'), findsNothing);
  });

  testWidgets('F2 negocio eliminado muestra No disponible en sus tres datos', (
    tester,
  ) async {
    await abrir(
      tester,
      datos: {
        ...datosDetalle,
        'negocio': {
          'id': 'n1',
          'nombre': '',
          'direccionTexto': '',
          'telefono': '',
        },
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('No disponible'), findsNWidgets(3));
    expect(find.text(''), findsNothing);
    expect(find.text('Corte de cabello'), findsOneWidget);
    expect(find.text('1 h 30 min'), findsOneWidget);
    expect(find.text(r'$150.50'), findsOneWidget);
  });

  testWidgets('C1 sin observaciones muestra el texto acordado', (tester) async {
    await abrir(tester, datos: {...datosDetalle, 'observaciones': null});
    await tester.pumpAndSettle();
    expect(find.text('Sin observaciones.'), findsOneWidget);
  });

  testWidgets('muestra el estado de carga hasta recibir la reserva', (
    tester,
  ) async {
    final espera = Completer<http.Response>();
    await abrir(tester, respuesta: (_) => espera.future);
    expect(find.text('Cargando tu reserva...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    espera.complete(http.Response(jsonEncode(datosDetalle), 200));
    await tester.pumpAndSettle();
    expect(find.text('Cargando tu reserva...'), findsNothing);
    expect(find.text('SRV-7KQ2MX'), findsOneWidget);
  });
  for (final estado in ['rechazada', 'cancelada']) {
    testWidgets('C2 muestra motivo y título para $estado', (tester) async {
      await abrir(
        tester,
        datos: {...datosDetalle, 'estado': estado, 'motivo': 'Sin personal.'},
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          estado == 'rechazada'
              ? 'Motivo del rechazo'
              : 'Motivo de la cancelación',
        ),
        findsOneWidget,
      );
      expect(find.text('Sin personal.'), findsOneWidget);
    });
  }

  testWidgets('D3 vencida usa su etiqueta sin motivo', (tester) async {
    await abrir(
      tester,
      datos: {
        ...datosDetalle,
        'estado': 'rechazada_vencimiento',
        'motivo': null,
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('Rechazada por vencimiento'), findsOneWidget);
    expect(find.text('Motivo del rechazo'), findsNothing);
    expect(find.text('Motivo de la cancelación'), findsNothing);
  });

  testWidgets('C2 cancelación sin motivo no inventa una sección', (
    tester,
  ) async {
    await abrir(
      tester,
      datos: {...datosDetalle, 'estado': 'cancelada', 'motivo': null},
    );
    await tester.pumpAndSettle();
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('Motivo de la cancelación'), findsNothing);
  });
  for (final codigo in [400, 404]) {
    testWidgets(
      'C3 y D1 $codigo oculta datos y permite volver a mis reservas',
      (tester) async {
        await abrir(tester, codigo: codigo);
        await tester.pumpAndSettle();
        expect(find.text('No encontramos esta reserva.'), findsOneWidget);
        expect(find.text('SRV-7KQ2MX'), findsNothing);
        expect(find.text('Reintentar'), findsNothing);
        await tester.tap(find.text('Volver a mis reservas'));
        // La ruta directa sin pantalla anterior vuelve a la lista.
        await tester.pumpAndSettle();
        expect(find.text('Mis reservas'), findsOneWidget);
        expect(find.byType(DetalleReservaPage), findsNothing);
      },
    );
  }
}
