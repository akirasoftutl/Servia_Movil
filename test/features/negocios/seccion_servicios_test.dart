import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/data/negocio.dart';
import 'package:servia/features/negocios/data/servicio.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import 'datos_prueba.dart';
import 'fakes.dart';
import 'utilidades_prueba.dart';

void main() {
  group('sección de servicios', () {
    testWidgets(
      'muestra exactamente la lista recibida y sus formatos en el mismo orden',
      (tester) async {
        final servicio = ServiciosServiceFalso();
        await abrirPerfil(tester, servicio);
        await verServicios(tester);
        expect(find.byType(ListTile), findsNWidgets(2));
        for (final texto in [
          'Z Corte',
          'A Masaje',
          r'$150',
          r'$150.50',
          '1 h 30 min',
          '30 min',
        ]) {
          expect(find.text(texto), findsOneWidget);
        }
        expect(
          tester.getTopLeft(find.text('Z Corte')).dy,
          lessThan(tester.getTopLeft(find.text('A Masaje')).dy),
        );
        expect(find.text('Reservar'), findsNothing);
      },
    );
    testWidgets('lista vacía tiene mensaje y mantiene el perfil', (
      tester,
    ) async {
      await abrirPerfil(tester, ServiciosServiceFalso()..servicios = []);
      expect(find.text(MensajesNegocios.sinServicios), findsOneWidget);
      expect(find.text('Salón Aurora'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });
    testWidgets(
      'error de servicios conserva perfil y reintenta solo la sección',
      (tester) async {
        final servicio = ServiciosServiceFalso()
          ..errorServicios = Exception('privado');
        await abrirPerfil(tester, servicio);
        expect(find.text('Salón Aurora'), findsOneWidget);
        expect(
          find.text('Calle Luna 12, Col. Centro, 37000, León, Guanajuato'),
          findsOneWidget,
        );
        expect(find.text('Domingo'), findsOneWidget);
        expect(find.text(MensajesNegocios.errorRed), findsOneWidget);
        expect(find.textContaining('privado'), findsNothing);
        await tester.ensureVisible(find.text('Reintentar'));
        servicio.errorServicios = null;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(servicio.consultasServicios, 2);
        expect(servicio.consultas, 1);
        expect(find.text('Z Corte'), findsOneWidget);
      },
    );
    testWidgets('espera al perfil y muestra carga propia sin ocultarlo', (
      tester,
    ) async {
      final servicio = ServiciosServiceFalso()
        ..pendiente = Completer<Negocio>()
        ..serviciosPendientes = Completer<List<Servicio>>();
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilNegocioPage(
            negocioId: 'abc123',
            negociosService: servicio,
          ),
        ),
      );
      expect(servicio.consultasServicios, 0);
      servicio.pendiente!.complete(Negocio.fromJson(negocioJson()));
      await tester.pump();
      await tester.pump();
      expect(find.text('Salón Aurora'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(servicio.consultasServicios, 1);
      servicio.serviciosPendientes!.complete(serviciosPrueba);
      await tester.pumpAndSettle();
      expect(find.text('Z Corte'), findsOneWidget);
    });
  });
}
