import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/features/negocios/data/disponibilidad.dart';
import 'package:servia/features/negocios/data/disponibilidad_service.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/detalle_servicio_page.dart';
import 'package:servia/features/negocios/pages/disponibilidad_page.dart';

import 'fakes.dart';

const sinDisponibilidad = 'No hay disponibilidad en este momento';

class DisponibilidadFalsa extends DisponibilidadService {
  List<DiaDisponibilidad> dias = [];
  Map<String, List<HoraDisponibilidad>> horas = {};
  Object? errorDias;
  Object? errorHoras;
  int consultasDias = 0;
  final consultasHoras = <String>[];

  @override
  Future<List<DiaDisponibilidad>> obtenerDias(
    String negocioId,
    String servicioId,
  ) async {
    consultasDias++;
    if (errorDias != null) throw errorDias!;
    return dias;
  }

  @override
  Future<List<HoraDisponibilidad>> obtenerHoras(
    String negocioId,
    String servicioId,
    String fecha,
  ) async {
    consultasHoras.add(fecha);
    if (errorHoras != null) throw errorHoras!;
    return horas[fecha] ?? [];
  }
}

DiaDisponibilidad dia(String fecha, bool disponible) =>
    DiaDisponibilidad(fecha: fecha, disponible: disponible);
HoraDisponibilidad hora(String hora, bool disponible) =>
    HoraDisponibilidad(hora: hora, disponible: disponible);

// 2026-11-03 10:15 en America/Mexico_City (UTC-6) son las 16:15 UTC.
final ahoraMexico = DateTime.utc(2026, 11, 3, 16, 15);

Future<void> abrir(
  WidgetTester tester,
  DisponibilidadService servicio, {
  DateTime Function()? ahora,
  void Function(SeleccionDisponibilidad?)? alVolver,
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            final seleccion = await Navigator.push<SeleccionDisponibilidad>(
              context,
              MaterialPageRoute(
                builder: (_) => DisponibilidadPage(
                  negocioId: 'abc123',
                  servicioId: 's2',
                  service: servicio,
                  ahora: ahora ?? () => ahoraMexico,
                ),
              ),
            );
            alVolver?.call(seleccion);
          },
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

// Desmonta la pantalla para cancelar el temporizador de vencimiento.
Future<void> cerrar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
}

DisponibilidadFalsa conDias() => DisponibilidadFalsa()
  ..dias = [
    dia('2026-11-02', false),
    dia('2026-11-03', true),
    dia('2026-11-04', false),
  ]
  ..horas = {
    '2026-11-03': [
      hora('09:30', true),
      hora('10:00', true),
      hora('10:30', true),
      hora('11:00', false),
      hora('11:30', true),
    ],
  };

void main() {
  group('disponibilidad de un servicio', () {
    testWidgets('deshabilita los días sin disponibilidad', (tester) async {
      final servicio = conDias();
      await abrir(tester, servicio);
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      expect(servicio.consultasHoras, isEmpty);
      expect(find.textContaining('Horarios del'), findsNothing);
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(servicio.consultasHoras, ['2026-11-03']);
      await cerrar(tester);
    });

    testWidgets('el calendario cubre los 30 días que devuelve la API', (
      tester,
    ) async {
      final inicio = DateTime.utc(2026, 11, 2);
      final servicio = conDias()
        ..dias = [
          for (var i = 0; i < 30; i++)
            dia(fechaIso(inicio.add(Duration(days: i))), true),
        ]
        ..horas = {
          '2026-12-01': [hora('11:00', true)],
        };
      await abrir(tester, servicio);
      expect(find.text('30'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(servicio.consultasHoras, ['2026-12-01']);
      expect(find.text('11:00'), findsOneWidget);
      await cerrar(tester);
    });

    testWidgets('muestra las horas de inicio y marca las ocupadas', (
      tester,
    ) async {
      SeleccionDisponibilidad? elegida;
      var volvio = false;
      final servicio = conDias();
      await abrir(
        tester,
        servicio,
        alVolver: (s) {
          volvio = true;
          elegida = s;
        },
      );
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(find.text('Horarios del 2026-11-03'), findsOneWidget);
      // 09:30 y 10:00 ya pasaron (son las 10:15 en Ciudad de México).
      expect(find.text('09:30'), findsNothing);
      expect(find.text('10:00'), findsNothing);
      for (final texto in ['10:30', '11:00', '11:30']) {
        expect(find.text(texto), findsOneWidget);
      }
      expect(find.text('Ocupado'), findsOneWidget);
      expect(find.text('Disponible'), findsNWidgets(2));
      await tester.tap(find.text('11:00'));
      await tester.pumpAndSettle();
      expect(volvio, isFalse);
      expect(find.text('Disponibilidad del servicio'), findsOneWidget);
      await tester.tap(find.text('11:30'));
      await tester.pumpAndSettle();
      expect(volvio, isTrue);
      expect(elegida!.negocioId, 'abc123');
      expect(elegida!.servicioId, 's2');
      expect(elegida!.fecha, '2026-11-03');
      expect(elegida!.hora, '11:30');
    });

    testWidgets('las horas pasadas se calculan en America/Mexico_City', (
      tester,
    ) async {
      // 16:15 UTC: en Ciudad de México son las 10:15, no las 16:15.
      final servicio = conDias();
      await abrir(tester, servicio);
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(find.text('10:30'), findsOneWidget);
      expect(find.text('10:00'), findsNothing);
      await cerrar(tester);
    });

    testWidgets('retira la hora que vence con la pantalla abierta', (
      tester,
    ) async {
      var ahora = ahoraMexico;
      await abrir(tester, conDias(), ahora: () => ahora);
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(find.text('10:30'), findsOneWidget);
      ahora = ahora.add(const Duration(minutes: 20));
      await tester.pump(const Duration(minutes: 20));
      expect(find.text('10:30'), findsNothing);
      expect(find.text('11:00'), findsOneWidget);
      await cerrar(tester);
    });

    testWidgets('sin ningún día disponible avisa que no hay disponibilidad', (
      tester,
    ) async {
      final servicio = DisponibilidadFalsa()
        ..dias = [dia('2026-11-02', false), dia('2026-11-03', false)];
      await abrir(tester, servicio);
      expect(find.text(sinDisponibilidad), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('sin días en la respuesta avisa que no hay disponibilidad', (
      tester,
    ) async {
      await abrir(tester, DisponibilidadFalsa());
      expect(find.text(sinDisponibilidad), findsOneWidget);
    });

    testWidgets('un día sin horas libres vigentes avisa que no hay', (
      tester,
    ) async {
      final servicio = conDias()
        ..horas = {
          '2026-11-03': [hora('09:00', true), hora('11:00', false)],
        };
      await abrir(tester, servicio);
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(find.text(sinDisponibilidad), findsOneWidget);
      await cerrar(tester);
    });

    testWidgets('error de red al cargar los días permite reintentar', (
      tester,
    ) async {
      final servicio = conDias()..errorDias = const SocketException('privado');
      await abrir(tester, servicio);
      expect(find.text(MensajesNegocios.errorRed), findsOneWidget);
      expect(find.textContaining('privado'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      servicio.errorDias = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(servicio.consultasDias, 2);
      expect(find.text(MensajesNegocios.errorRed), findsNothing);
      expect(find.byType(CalendarDatePicker), findsOneWidget);
    });

    testWidgets('error de red al cargar las horas permite reintentar', (
      tester,
    ) async {
      final servicio = conDias()..errorHoras = TimeoutException('privado');
      await abrir(tester, servicio);
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(find.text(MensajesNegocios.errorRed), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      servicio.errorHoras = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(servicio.consultasHoras, ['2026-11-03', '2026-11-03']);
      expect(find.text('11:30'), findsOneWidget);
      await cerrar(tester);
    });

    testWidgets('se consulta sin iniciar sesión (sin token)', (tester) async {
      final encabezados = <Map<String, String>>[];
      final servicio = DisponibilidadService(
        api: ApiClient(
          client: MockClient((r) async {
            encabezados.add(r.headers);
            return http.Response(
              jsonEncode([
                {'fecha': '2026-11-03', 'disponible': true},
              ]),
              200,
            );
          }),
        ),
      );
      await abrir(tester, servicio);
      expect(encabezados, isNotEmpty);
      expect(encabezados.any((h) => h.containsKey('Authorization')), isFalse);
      expect(find.byType(CalendarDatePicker), findsOneWidget);
    });

    testWidgets(
      'Reservar en el detalle abre la disponibilidad y avisa la hora',
      (tester) async {
        SeleccionDisponibilidad? elegida;
        final servicio = conDias();
        await tester.binding.setSurfaceSize(const Size(800, 3000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: DetalleServicioPage(
              negocioId: 'abc123',
              servicioId: 's2',
              aceptaReservas: true,
              negociosService: DetalleServiceFalso(),
              disponibilidadService: servicio,
              onSeleccionDisponibilidad: (s) => elegida = s,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reservar'));
        await tester.pumpAndSettle();
        expect(find.byType(DisponibilidadPage), findsOneWidget);
        expect(servicio.consultasDias, 1);
        await tester.tap(find.text('3'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('11:30'));
        await tester.pumpAndSettle();
        expect(elegida?.fecha, '2026-11-03');
        expect(elegida?.hora, '11:30');
        expect(find.byType(DisponibilidadPage), findsNothing);
      },
    );
  });
}
