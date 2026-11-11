import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/reservas/mensajes.dart';
import 'package:servia/features/reservas/pages/confirmacion_reserva_page.dart';
import 'package:servia/features/reservas/pages/resumen_reserva_page.dart';
import 'package:servia/features/reservas/resultado_reserva.dart';

import 'fakes.dart';

Future<void> enviar(WidgetTester tester) async {
  await tester.ensureVisible(find.text(MensajesReservas.enviar));
  await tester.tap(find.text(MensajesReservas.enviar));
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  testWidgets('muestra negocio, servicio, fecha, hora, duración, precio y contacto',
      (tester) async {
    await abrirResumen(tester, perfil: PerfilFalso(telefono: '4771234567'));
    for (final texto in [
      'Barbería Central',
      'Corte de cabello',
      'martes 10 de noviembre de 2026',
      '10:00',
      '1 h 30 min',
      r'$150',
      MensajesReservas.contacto,
    ]) {
      expect(find.text(texto), findsOneWidget, reason: texto);
    }
    expect(
      find.text('Ana Pérez\nana@test.com\n4771234567'),
      findsOneWidget,
    );
  });

  testWidgets('permite observaciones opcionales de hasta 500 caracteres y las envía',
      (tester) async {
    final reservas = ReservasFalso();
    await abrirResumen(tester, reservas: reservas);
    await tester.enterText(find.byType(TextField), 'a' * 600);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 500);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text.length,
      500,
    );
    await tester.enterText(find.byType(TextField), 'Llego 5 minutos antes.');
    await enviar(tester);
    expect(reservas.solicitudes.single.observaciones, 'Llego 5 minutos antes.');
  });

  testWidgets('sin observaciones se envía igual (son opcionales)', (tester) async {
    final reservas = ReservasFalso();
    await abrirResumen(tester, reservas: reservas);
    await enviar(tester);
    expect(reservas.solicitudes.single.toJson(), isNot(contains('observaciones')));
    expect(find.byType(ConfirmacionReservaPage), findsOneWidget);
  });

  testWidgets('envía el inicio ISO con zona de México, el servicio y el token',
      (tester) async {
    final reservas = ReservasFalso();
    await abrirResumen(tester, reservas: reservas);
    await enviar(tester);
    final s = reservas.solicitudes.single;
    expect(s.negocioId, 'n1');
    expect(s.servicioId, 's1');
    expect(s.inicio, '2026-11-10T10:00:00-06:00');
    expect(reservas.tokens.single, 'token');
  });

  group('aviso de cancelación (D4)', () {
    testWidgets('cita en menos de 24 horas: avisa que no se podrá cancelar',
        (tester) async {
      await abrirResumen(tester, ahora: DateTime.utc(2026, 11, 9, 16, 30));
      expect(find.text(MensajesReservas.sinCancelacion), findsOneWidget);
    });

    testWidgets('cita con más de 24 horas: no lo muestra', (tester) async {
      await abrirResumen(tester, ahora: DateTime.utc(2026, 11, 8, 12));
      expect(find.text(MensajesReservas.sinCancelacion), findsNothing);
    });

    testWidgets('siempre avisa que el negocio tiene hasta 2 horas', (tester) async {
      await abrirResumen(tester);
      expect(find.text(MensajesReservas.avisoDosHoras), findsOneWidget);
    });
  });

  testWidgets('no permite el doble envío: deshabilita el botón mientras envía',
      (tester) async {
    final espera = Completer<void>();
    final reservas = ReservasFalso(espera: espera);
    await abrirResumen(tester, reservas: reservas);
    await enviar(tester);
    expect(find.text(MensajesReservas.enviando), findsOneWidget);
    final boton = find.widgetWithText(FilledButton, MensajesReservas.enviando);
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);
    await tester.tap(boton, warnIfMissed: false);
    await tester.pump();
    expect(reservas.solicitudes, hasLength(1));
    espera.complete();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.byType(ConfirmacionReservaPage), findsOneWidget);
    expect(reservas.solicitudes, hasLength(1));
  });

  testWidgets('201: muestra la confirmación con folio, Pendiente y las 2 horas',
      (tester) async {
    final probador = await abrirResumen(tester);
    await enviar(tester);
    expect(find.byType(ResumenReservaPage), findsNothing);
    expect(find.text('SRV-7KQ2MX'), findsOneWidget);
    expect(find.text(MensajesReservas.estadoPendiente), findsOneWidget);
    expect(find.text(MensajesReservas.avisoDosHoras), findsOneWidget);
    await tester.tap(find.text(MensajesReservas.volverAlInicio));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('abrir'), findsOneWidget);
    expect(probador.resultado, ResultadoReserva.enviada);
  });

  testWidgets('409: avisa que el horario ya no está libre y regresa a elegir',
      (tester) async {
    final probador = await abrirResumen(
      tester,
      reservas: ReservasFalso(error: const ApiException(409, 'ocupado')),
    );
    await enviar(tester);
    expect(find.byType(ResumenReservaPage), findsNothing);
    expect(probador.resultado, ResultadoReserva.horarioOcupado);
  });

  final errores = <String, (Object, String)>{
    '400': (const ApiException(400, 'x'), MensajesReservas.datosInvalidos),
    '403': (const ApiException(403, 'x'), MensajesReservas.soloClientes),
    '404': (const ApiException(404, 'x'), MensajesReservas.noDisponible),
    '500': (const ApiException(500, 'x'), MensajesReservas.errorApi),
    'red': (Exception('sin red'), MensajesReservas.errorRed),
    'tiempo agotado': (TimeoutException('x'), MensajesReservas.errorRed),
  };
  errores.forEach((nombre, caso) {
    testWidgets('$nombre: mensaje claro, sin quedarse cargando y se puede reintentar',
        (tester) async {
      final reservas = ReservasFalso(error: caso.$1);
      await abrirResumen(tester, reservas: reservas);
      await enviar(tester);
      await tester.ensureVisible(find.text(caso.$2));
      expect(find.text(caso.$2), findsOneWidget);
      expect(find.text(MensajesReservas.enviando), findsNothing);
      final boton = find.widgetWithText(FilledButton, MensajesReservas.enviar);
      expect(tester.widget<FilledButton>(boton).onPressed, isNotNull);
      expect(find.byType(ResumenReservaPage), findsOneWidget);
    });
  });

  testWidgets('401: avisa que la sesión venció y la cierra para pedirla de nuevo',
      (tester) async {
    final sesion = SesionFalsa();
    await abrirResumen(
      tester,
      sesion: sesion,
      reservas: ReservasFalso(error: const ApiException(401, 'x')),
    );
    await enviar(tester);
    await tester.ensureVisible(find.text(MensajesReservas.sesionVencida));
    expect(find.text(MensajesReservas.sesionVencida), findsOneWidget);
    expect(sesion.cierres, 1);
  });

  testWidgets('una cuenta de negocio no puede reservar: sin botón activo',
      (tester) async {
    final reservas = ReservasFalso();
    await abrirResumen(tester, perfil: PerfilFalso(tipo: 'negocio'), reservas: reservas);
    expect(find.text(MensajesReservas.soloClientes), findsOneWidget);
    final boton = find.widgetWithText(FilledButton, MensajesReservas.enviar);
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);
    await tester.tap(boton, warnIfMissed: false);
    await tester.pump();
    expect(reservas.solicitudes, isEmpty);
  });

  testWidgets('si no se pueden cargar los datos de contacto ofrece reintentar y no envía',
      (tester) async {
    final reservas = ReservasFalso();
    await abrirResumen(
      tester,
      perfil: PerfilFalso(error: Exception('sin red')),
      reservas: reservas,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    final boton = find.widgetWithText(FilledButton, MensajesReservas.enviar);
    expect(tester.widget<FilledButton>(boton).onPressed, isNull);
    expect(reservas.solicitudes, isEmpty);
  });
}
