import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/servicio.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/detalle_servicio_page.dart';

import 'seccion_servicios_test.dart' show ServiciosServiceFalso, abrirPerfil;

const detallePrueba = Servicio(
  id: 's2',
  nombre: 'Z Corte',
  descripcion: 'Lavado y corte de cabello',
  precio: 150.5,
  duracionMin: 90,
);

class DetalleServiceFalso extends ServiciosServiceFalso {
  Object? errorDetalle;
  int consultasDetalle = 0;
  String? negocioConsultado;
  String? servicioConsultado;
  Completer<Servicio>? detallePendiente;
  @override
  Future<Servicio> obtenerServicio(String negocioId, String servicioId) async {
    consultasDetalle++;
    negocioConsultado = negocioId;
    servicioConsultado = servicioId;
    if (errorDetalle != null) throw errorDetalle!;
    return detallePendiente?.future ?? detallePrueba;
  }
}

Future<void> mostrarDetalle(
  WidgetTester tester,
  DetalleServiceFalso servicio, {
  bool acepta = true,
  String negocioId = 'abc123',
  String servicioId = 's2',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DetalleServicioPage(
        negocioId: negocioId,
        servicioId: servicioId,
        aceptaReservas: acepta,
        negociosService: servicio,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('detalle del servicio', () {
    for (final acepta in [true, false]) {
      testWidgets(
        'tocar un servicio abre su detalle y respeta aceptaReservas $acepta',
        (tester) async {
          final servicio = DetalleServiceFalso()..aceptaReservas = acepta;
          await abrirPerfil(tester, servicio);
          await tester.ensureVisible(find.text('Z Corte'));
          await tester.tap(find.text('Z Corte'));
          await tester.pumpAndSettle();
          expect(servicio.negocioConsultado, 'abc123');
          expect(servicio.servicioConsultado, 's2');
          expect(find.byType(DetalleServicioPage), findsOneWidget);
          for (final texto in [
            'Z Corte',
            'Lavado y corte de cabello',
            r'$150.50',
            '1 h 30 min',
          ]) {
            expect(find.text(texto), findsOneWidget);
          }
          expect(find.text('Reservar'), acepta ? findsOneWidget : findsNothing);
          if (acepta) {
            await tester.tap(find.text('Reservar'));
            await tester.pump();
            expect(find.text(MensajesNegocios.reservaProxima), findsOneWidget);
            expect(servicio.consultasDetalle, 1);
          }
          await tester.pageBack();
          await tester.pumpAndSettle();
          expect(find.byType(DetalleServicioPage), findsNothing);
          expect(find.text('Salón Aurora'), findsOneWidget);
        },
      );
    }
    testWidgets('404 de detalle muestra no disponible sin reintentar', (
      tester,
    ) async {
      await mostrarDetalle(
        tester,
        DetalleServiceFalso()
          ..errorDetalle = const ApiException(404, 'privado'),
      );
      expect(find.text(MensajesNegocios.servicioNoDisponible), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('Reservar'), findsNothing);
    });
    testWidgets('red permite reintentar el detalle y recuperar descripción', (
      tester,
    ) async {
      final servicio = DetalleServiceFalso()
        ..errorDetalle = Exception('privado');
      await mostrarDetalle(tester, servicio);
      expect(find.text(MensajesNegocios.errorRed), findsOneWidget);
      expect(find.textContaining('privado'), findsNothing);
      servicio.errorDetalle = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(servicio.consultasDetalle, 2);
      expect(find.text('Lavado y corte de cabello'), findsOneWidget);
    });
    for (final error in [
      TimeoutException('privado'),
      const ApiException(500, 'privado'),
      const FormatException('privado'),
    ]) {
      testWidgets('error seguro del detalle ${error.runtimeType}', (
        tester,
      ) async {
        await mostrarDetalle(
          tester,
          DetalleServiceFalso()..errorDetalle = error,
        );
        expect(
          find.text(MensajesNegocios.mensajeDeError(error)),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.textContaining('privado'), findsNothing);
      });
    }
    testWidgets('ids inválidos del detalle no consultan', (tester) async {
      for (final par in [('a/b', 's2'), ('abc123', '')]) {
        final servicio = DetalleServiceFalso();
        await mostrarDetalle(
          tester,
          servicio,
          negocioId: par.$1,
          servicioId: par.$2,
        );
        expect(servicio.consultasDetalle, 0);
        expect(
          find.text(MensajesNegocios.servicioNoDisponible),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
    testWidgets('carga del detalle y salida antes de recibir respuesta', (
      tester,
    ) async {
      final servicio = DetalleServiceFalso()
        ..detallePendiente = Completer<Servicio>();
      await tester.pumpWidget(
        MaterialApp(
          home: DetalleServicioPage(
            negocioId: 'abc123',
            servicioId: 's2',
            aceptaReservas: true,
            negociosService: servicio,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      servicio.detallePendiente!.complete(detallePrueba);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
