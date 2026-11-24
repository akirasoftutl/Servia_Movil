import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/reservas/mensajes.dart';

import 'escenario_reprogramar.dart';

const _volverPendiente =
    'Tu reserva volverá a quedar Pendiente y el negocio tendrá que aceptarla de nuevo.';
const _ocupado =
    'El horario elegido ya no está disponible. Elige otro horario.';

void main() {
  group('botón y explicación según la API (HU-C74)', () {
    testWidgets('reprogramable true muestra «Cambiar fecha u hora»', (t) async {
      await EscenarioReprogramar().abrir(t);
      expect(find.text('Cambiar fecha u hora'), findsOneWidget);
      expect(find.byKey(const ValueKey('reprogramar-reserva')), findsOneWidget);
    });

    testWidgets('con false, sin botón y con el motivo de la API', (t) async {
      await EscenarioReprogramar(
        detalle: detalleApi(
          estado: 'confirmada',
          reprogramable: false,
          motivoNoReprogramable:
              'Solo puedes cambiar una reserva confirmada hasta 24 horas antes de la cita.',
        ),
      ).abrir(t);
      expect(find.text('Cambiar fecha u hora'), findsNothing);
      expect(
        find.text(
          'Solo puedes cambiar una reserva confirmada hasta 24 horas antes de la cita.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('la app no recalcula las 24 h: manda lo que dice reprogramable', (
      t,
    ) async {
      // Confirmada con la cita en menos de 24 h, pero la API dice true.
      await EscenarioReprogramar(
        detalle: detalleApi(
          estado: 'confirmada',
          inicio: '2026-11-04T10:00:00.000Z',
          reprogramable: true,
        ),
      ).abrir(t);
      expect(find.text('Cambiar fecha u hora'), findsOneWidget);
    });

    testWidgets('en estados terminales no hay botón ni texto de motivo', (
      t,
    ) async {
      await EscenarioReprogramar(
        detalle: detalleApi(
          estado: 'cancelada',
          reprogramable: false,
          reprogramableHasta: null,
          motivoNoReprogramable:
              'Esta reserva ya no se puede cambiar porque está cancelada.',
        ),
      ).abrir(t);
      expect(find.text('Cambiar fecha u hora'), findsNothing);
      expect(find.textContaining('ya no se puede cambiar'), findsNothing);
    });
  });

  group('cambiar fecha y hora', () {
    testWidgets('éxito: consulta la ruta de la reserva, resume y envía', (
      t,
    ) async {
      final e = EscenarioReprogramar()..cuerpoPatch = EscenarioReprogramar.exito();
      await e.abrir(t);
      await e.hastaElResumen(t);

      // Pantalla de resumen: ahora, nueva fecha y aviso (RN-43, RN-55).
      expect(find.text('Confirmar cambio'), findsOneWidget);
      expect(find.text('martes 10 de noviembre de 2026'), findsOneWidget);
      expect(find.text('jueves 12 de noviembre de 2026'), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
      expect(find.text(_volverPendiente), findsOneWidget);
      expect(find.text('Sí, cambiar'), findsOneWidget);
      expect(find.text('No, volver'), findsOneWidget);
      expect(e.envios, isEmpty, reason: 'nada se envía hasta confirmar');

      // La disponibilidad salió de la ruta privada, con el token.
      expect(e.consultasDisponibilidad, isNotEmpty);
      for (final c in e.consultasDisponibilidad) {
        expect(c.url.path, '/reservas/mias/r1/disponibilidad');
        expect(c.url.queryParameters.containsKey('servicioId'), isFalse);
      }

      // El servidor ya tiene la reserva movida y Pendiente.
      e.detalle = detalleApi(
        inicio: '2026-11-12T15:30:00.000Z',
        fin: '2026-11-12T16:30:00.000Z',
      );
      await t.tap(find.text('Sí, cambiar'));
      await t.pumpAndSettle();

      final envio = e.envios.single;
      expect(envio.url.path, '/reservas/mias/r1/reprogramar');
      expect(jsonDecode(envio.body), {'inicio': '2026-11-12T09:30:00-06:00'});

      // De vuelta en el detalle, recargado, Pendiente y con la fecha nueva.
      expect(find.text('Detalle de la reserva'), findsOneWidget);
      expect(e.lecturasDetalle, hasLength(2));
      expect(find.text('jueves 12 de noviembre de 2026'), findsWidgets);
      expect(find.text('Pendiente'), findsWidgets);
      expect(
        find.text('Tu reserva se cambió. El negocio debe aceptarla de nuevo.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Tu reserva quedó Pendiente'),
        findsOneWidget,
      );
    });

    testWidgets('el horario de la propia cita sale libre al elegir', (t) async {
      final e = EscenarioReprogramar();
      await e.abrir(t);
      await t.tap(find.text('Cambiar fecha u hora'));
      await t.pumpAndSettle();
      await t.tap(find.text('Elegir nueva fecha y hora'));
      await t.pumpAndSettle();
      await t.tap(find.text('10'));
      await t.pumpAndSettle();
      // 10:00 es la cita actual: la API la manda libre y la app la deja elegir.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('hora-10:00')),
          matching: find.text('Elegir'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('hora-10:30')),
          matching: find.text('Ocupado'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('«No, volver» no envía nada', (t) async {
      final e = EscenarioReprogramar();
      await e.abrir(t);
      await e.hastaElResumen(t);
      await t.tap(find.text('No, volver'));
      await t.pumpAndSettle();
      expect(find.text('Confirmar cambio'), findsNothing);
      expect(find.text('Elegir nueva fecha y hora'), findsOneWidget);
      expect(e.envios, isEmpty);
    });

    testWidgets('al enviar el botón se deshabilita y no hay doble envío', (
      t,
    ) async {
      final espera = Completer<void>();
      final e = EscenarioReprogramar()
        ..esperaPatch = espera
        ..cuerpoPatch = EscenarioReprogramar.exito();
      await e.abrir(t);
      await e.hastaElResumen(t);
      await t.tap(find.text('Sí, cambiar'));
      await t.pump();
      final boton = find.byKey(const ValueKey('confirmar-cambio'));
      expect(t.widget<FilledButton>(boton).onPressed, isNull);
      expect(find.text('Cambiando...'), findsOneWidget);
      await t.tap(boton, warnIfMissed: false);
      await t.pump();
      expect(e.envios, hasLength(1));
      espera.complete();
      await t.pumpAndSettle();
      expect(e.envios, hasLength(1));
    });
  });

  group('errores de la API', () {
    testWidgets('409 horario ocupado: vuelve a elegir con el mensaje y la reserva no cambia', (
      t,
    ) async {
      final e = EscenarioReprogramar()
        ..codigoPatch = 409
        ..cuerpoPatch = errorNest(409, _ocupado, 'Conflict');
      await e.abrir(t);
      await e.hastaElResumen(t);
      await t.tap(find.text('Sí, cambiar'));
      await t.pumpAndSettle();

      // Otra vez la selección de horario, con el aviso de la API.
      expect(find.text('Disponibilidad del servicio'), findsOneWidget);
      expect(find.text(_ocupado), findsOneWidget);
      expect(e.envios, hasLength(1));
      // Elige otro horario y el segundo envío sale con el nuevo.
      e
        ..codigoPatch = 200
        ..cuerpoPatch = EscenarioReprogramar.exito();
      await t.tap(find.text('11'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('hora-10:00')));
      await t.pumpAndSettle();
      await t.tap(find.text('Sí, cambiar'));
      await t.pumpAndSettle();
      expect(e.envios, hasLength(2));
      expect(jsonDecode(e.envios.last.body), {
        'inicio': '2026-11-11T10:00:00-06:00',
      });
    });

    testWidgets('409 porque ya no se puede cambiar: vuelve al detalle con el motivo', (
      t,
    ) async {
      const motivo =
          'Solo puedes cambiar una reserva confirmada hasta 24 horas antes de la cita.';
      final e = EscenarioReprogramar()
        ..codigoPatch = 409
        ..cuerpoPatch = errorNest(409, motivo, 'Conflict');
      await e.abrir(t);
      await e.hastaElResumen(t);
      e.detalle = detalleApi(
        estado: 'confirmada',
        reprogramable: false,
        motivoNoReprogramable: motivo,
      );
      await t.tap(find.text('Sí, cambiar'));
      await t.pumpAndSettle();
      expect(find.text('Detalle de la reserva'), findsOneWidget);
      expect(find.text('Cambiar fecha u hora'), findsNothing);
      expect(find.text(motivo), findsWidgets);
      expect(find.text('Disponibilidad del servicio'), findsNothing);
    });

    testWidgets('404: «Esta reserva ya no está disponible.»', (t) async {
      final e = EscenarioReprogramar()
        ..codigoPatch = 404
        ..cuerpoPatch = errorNest(404, 'La reserva no existe.', 'Not Found');
      await e.abrir(t);
      await e.hastaElResumen(t);
      await t.tap(find.text('Sí, cambiar'));
      await t.pumpAndSettle();
      expect(find.text(MensajesReservas.reservaYaNoDisponible), findsWidgets);
      expect(find.text('Confirmar cambio'), findsNothing);
    });

    testWidgets('401: sesión inválida, sin reintento', (t) async {
      final e = EscenarioReprogramar()
        ..codigoPatch = 401
        ..cuerpoPatch = errorNest(401, 'Token inválido.', 'Unauthorized');
      await e.abrir(t);
      await e.hastaElResumen(t);
      await t.tap(find.text('Sí, cambiar'));
      await t.pumpAndSettle();
      expect(
        find.text('Tu sesión ya no es válida. Inicia sesión de nuevo.'),
        findsOneWidget,
      );
      expect(e.envios, hasLength(1));
    });

    testWidgets('400 «No hay cambios»: muestra el mensaje de la API', (t) async {
      const sinCambios =
          'No hay cambios: elige otra fecha, otra hora u otro servicio.';
      final e = EscenarioReprogramar()
        ..codigoPatch = 400
        ..cuerpoPatch = errorNest(400, sinCambios, 'Bad Request');
      await e.abrir(t);
      await e.hastaElResumen(t, dia: '10', hora: '10:00');
      await t.tap(find.text('Sí, cambiar'));
      await t.pumpAndSettle();
      expect(find.text(sinCambios), findsOneWidget);
    });

    testWidgets('sin conexión: mensaje de red y se puede reintentar', (t) async {
      final e = EscenarioReprogramar()..sinRedPatch = true;
      await e.abrir(t);
      await e.hastaElResumen(t);
      await t.tap(find.text('Sí, cambiar'));
      await t.pumpAndSettle();
      expect(
        find.text('No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Sí, cambiar'), findsOneWidget);
      expect(
        t.widget<FilledButton>(find.byKey(const ValueKey('confirmar-cambio'))).onPressed,
        isNotNull,
      );
    });

    testWidgets('sin sesión al consultar horarios: mensaje de sesión, no de red', (
      t,
    ) async {
      final e = EscenarioReprogramar()..codigoDisponibilidad = 401;
      await e.abrir(t);
      await t.tap(find.text('Cambiar fecha u hora'));
      await t.pumpAndSettle();
      await t.tap(find.text('Elegir nueva fecha y hora'));
      await t.pumpAndSettle();
      expect(
        find.text('Tu sesión ya no es válida. Inicia sesión de nuevo.'),
        findsOneWidget,
      );
    });
  });

  group('cambiar de servicio (HU-C73)', () {
    testWidgets('lista los servicios del negocio y envía servicioId con precio y duración en el resumen', (
      t,
    ) async {
      final e = EscenarioReprogramar()
        ..cuerpoPatch = EscenarioReprogramar.exito(precio: 300.5, duracionMin: 90);
      await e.abrir(t);
      await e.hastaElResumen(t, servicio: 'Masaje relajante');

      // La disponibilidad se pidió para el servicio nuevo.
      expect(
        e.consultasDisponibilidad.every(
          (c) => c.url.queryParameters['servicioId'] == 's2',
        ),
        isTrue,
      );
      // Resumen con el precio y la duración del servicio nuevo y los de antes.
      expect(find.text('Masaje relajante'), findsWidgets);
      expect(find.textContaining('\$300.50'), findsWidgets);
      expect(find.textContaining('1 h 30 min'), findsWidgets);
      expect(find.textContaining('Corte de cabello'), findsWidgets);

      await t.tap(find.text('Sí, cambiar'));
      await t.pumpAndSettle();
      expect(jsonDecode(e.envios.single.body), {
        'inicio': '2026-11-12T09:30:00-06:00',
        'servicioId': 's2',
      });
    });

    testWidgets('si falla la lista de servicios se puede reintentar', (t) async {
      final e = EscenarioReprogramar()..codigoServicios = 500;
      await e.abrir(t);
      await t.tap(find.text('Cambiar fecha u hora'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cambiar de servicio'));
      await t.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Masaje relajante'), findsNothing);
      e.codigoServicios = 200;
      await t.tap(find.text('Reintentar'));
      await t.pumpAndSettle();
      expect(find.text('Masaje relajante'), findsOneWidget);
    });
  });

  group('zonas horarias y límite de la API', () {
    testWidgets('el plazo de una Confirmada sale de reprogramableHasta en hora de México', (
      t,
    ) async {
      final e = EscenarioReprogramar(
        detalle: detalleApi(
          estado: 'confirmada',
          reprogramableHasta: '2026-11-09T16:00:00.000Z',
        ),
      );
      await e.abrir(t);
      await t.tap(find.text('Cambiar fecha u hora'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('lunes 9 de noviembre de 2026'),
        findsOneWidget,
      );
      expect(find.textContaining('10:00'), findsWidgets);
    });

    testWidgets('la cita se muestra en México aunque el instante llegue en UTC', (
      t,
    ) async {
      // 2026-11-10T05:30Z es lunes 9 a las 23:30 en México.
      await EscenarioReprogramar(
        detalle: detalleApi(inicio: '2026-11-10T05:30:00.000Z'),
      ).abrir(t);
      await t.tap(find.text('Cambiar fecha u hora'));
      await t.pumpAndSettle();
      expect(find.text('lunes 9 de noviembre de 2026'), findsWidgets);
      expect(find.text('23:30'), findsWidgets);
    });
  });
}
