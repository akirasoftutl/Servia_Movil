import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/theme/tema_servia.dart';
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
  testWidgets(
    'estilo del rediseño: cabecera propia, tarjetas y chip de lista',
    (tester) async {
      await abrir(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.white,
      );
      final titulo = tester.widget<Text>(find.text('Detalle de la reserva'));
      expect(titulo.style?.fontSize, 20);
      expect(titulo.style?.color, const Color(0xFF111827));
      final tarjeta = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Fecha y hora'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoracion = tarjeta.decoration! as BoxDecoration;
      expect(decoracion.border, Border.all(color: const Color(0xFFE5E7EB)));
      expect(decoracion.borderRadius, BorderRadius.circular(18));
      expect(decoracion.boxShadow, isNotEmpty);
      // Pendiente con los mismos colores que `_BadgeEstadoReserva` de la lista.
      final chip = tester.widget<Container>(
        find.byKey(const ValueKey('estado-reserva')),
      );
      expect(
        (chip.decoration! as BoxDecoration).color,
        const Color(0xFFFEF3C7),
      );
      expect(
        tester.widget<Text>(find.text('Pendiente')).style?.color,
        const Color(0xFFB45309),
      );
    },
  );

  testWidgets('la flecha de la cabecera regresa a la pantalla anterior', (
    tester,
  ) async {
    await abrir(tester);
    await tester.pumpAndSettle();
    // Como pantalla inicial no hay a dónde volver: no se muestra la flecha.
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    final detalle = tester.widget<DetalleReservaPage>(
      find.byType(DetalleReservaPage),
    );
    Navigator.of(tester.element(find.byType(DetalleReservaPage))).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalleReservaPage(
          id: 'r2',
          authService: detalle.authService,
          reservasService: detalle.reservasService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DetalleReservaPage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DetalleReservaPage>(find.byType(DetalleReservaPage)).id,
      'r1',
    );
  });

  testWidgets('C1 muestra la reserva completa y la fecha de México', (
    tester,
  ) async {
    await abrir(tester);
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    expect(find.text('SRV-7KQ2MX'), findsOneWidget);
    expect(find.byKey(const ValueKey('estado-reserva')), findsOneWidget);
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
  for (final codigo in [401, 403]) {
    testWidgets('C4 y D2 $codigo muestra sesión vencida sin reintento', (
      tester,
    ) async {
      await abrir(tester, codigo: codigo);
      await tester.pumpAndSettle();
      expect(
        find.text('Tu sesión ya no es válida. Inicia sesión de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('SRV-7KQ2MX'), findsNothing);
    });
  }

  testWidgets('C4 sin sesión no consulta datos', (tester) async {
    var consultas = 0;
    await abrir(
      tester,
      sesion: SesionFalsa(conSesion: false),
      respuesta: (_) async {
        consultas++;
        return http.Response(jsonEncode(datosDetalle), 200);
      },
    );
    await tester.pumpAndSettle();
    expect(consultas, 0);
    expect(
      find.text('Tu sesión ya no es válida. Inicia sesión de nuevo.'),
      findsOneWidget,
    );
  });

  testWidgets('C4 red permite Reintentar y recupera el detalle', (
    tester,
  ) async {
    var consultas = 0;
    await abrir(
      tester,
      respuesta: (r) async {
        expect(r.url.path, '/reservas/mias/r1');
        expect(r.headers['Authorization'], 'Bearer token');
        if (++consultas == 1) throw Exception('Sin conexión');
        return http.Response(jsonEncode(datosDetalle), 200);
      },
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(consultas, 2);
    expect(find.text('SRV-7KQ2MX'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });
}
