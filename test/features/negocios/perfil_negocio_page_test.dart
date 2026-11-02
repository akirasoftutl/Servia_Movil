import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/negocio.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/formatos.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import 'datos_prueba.dart';
import 'fakes.dart';

Future<void> mostrarPerfil(
  WidgetTester tester,
  NegociosServiceFalso servicio, {
  String id = 'abc123',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilNegocioPage(negocioId: id, negociosService: servicio),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('formatea horario y descanso', () {
    expect(
      formatearHorario(const HorarioDia(abre: '09:00', cierra: '18:00')),
      '09:00 – 18:00',
    );
    expect(formatearHorario(null), 'Descanso');
  });
  group('perfil del negocio', () {
    testWidgets('muestra los siete datos y las siete filas en orden', (
      tester,
    ) async {
      await mostrarPerfil(tester, NegociosServiceFalso());
      for (final texto in [
        'Salón Aurora',
        'Cuidado personal',
        'Cabello y barba',
        'Calle Luna 12',
        '4771234567',
        'aurora@example.test',
        'Horario de atención',
      ]) {
        expect(find.text(texto), findsOneWidget);
      }
      final posiciones = <double>[];
      for (final dia in diasSemana.values) {
        expect(find.text(dia), findsOneWidget);
        posiciones.add(tester.getTopLeft(find.text(dia)).dy);
      }
      expect(posiciones, orderedEquals([...posiciones]..sort()));
      expect(find.text('09:00 – 18:00'), findsNWidgets(6));
      expect(find.text('Descanso'), findsOneWidget);
      expect(find.text('Servicios'), findsOneWidget);
    });
    for (final acepta in [true, false]) {
      testWidgets('respeta aceptaReservas $acepta sin recalcular horario', (
        tester,
      ) async {
        await mostrarPerfil(
          tester,
          NegociosServiceFalso(aceptaReservas: acepta),
        );
        expect(
          find.text(
            acepta
                ? MensajesNegocios.aceptaReservas
                : MensajesNegocios.noAceptaReservas,
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            acepta
                ? MensajesNegocios.noAceptaReservas
                : MensajesNegocios.aceptaReservas,
          ),
          findsNothing,
        );
      });
    }
    for (final falla in [true, false]) {
      testWidgets(
        'catálogo sin coincidencia o fallido conserva categoriaId $falla',
        (tester) async {
          await mostrarPerfil(
            tester,
            NegociosServiceFalso(
              errorCategorias: falla ? Exception('privado') : null,
              catalogoVacio: !falla,
            ),
          );
          expect(find.text('cabello'), findsOneWidget);
          expect(find.text('Salón Aurora'), findsOneWidget);
          expect(find.text(MensajesNegocios.errorRed), findsNothing);
        },
      );
    }
    testWidgets('muestra carga mientras espera la consulta', (tester) async {
      final servicio = NegociosServiceFalso()..pendiente = Completer<Negocio>();
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilNegocioPage(
            negocioId: 'abc123',
            negociosService: servicio,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      servicio.pendiente!.complete(Negocio.fromJson(negocioJson()));
      await tester.pumpAndSettle();
      expect(find.text('Salón Aurora'), findsOneWidget);
    });
    testWidgets('error de red permite reintentar y recuperar el perfil', (
      tester,
    ) async {
      final servicio = NegociosServiceFalso(error: Exception('privado'));
      await mostrarPerfil(tester, servicio);
      expect(find.text(MensajesNegocios.errorRed), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      servicio.error = null;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(servicio.consultas, 2);
      expect(find.text('Salón Aurora'), findsOneWidget);
    });
    for (final error in [
      TimeoutException('privado'),
      const SocketException('privado'),
      http.ClientException('privado'),
      const FormatException('privado'),
      const ApiException(500, 'privado'),
    ]) {
      testWidgets('presenta mensaje seguro para ${error.runtimeType}', (
        tester,
      ) async {
        await mostrarPerfil(tester, NegociosServiceFalso(error: error));
        final mensaje = error is FormatException
            ? MensajesNegocios.errorCarga
            : error is ApiException
            ? MensajesNegocios.errorApi
            : MensajesNegocios.errorRed;
        expect(find.text(mensaje), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.textContaining('privado'), findsNothing);
      });
    }
    testWidgets('400 conserva el mensaje del perfil y permite reintentar', (
      tester,
    ) async {
      await mostrarPerfil(
        tester,
        NegociosServiceFalso(error: const ApiException(400, 'privado')),
      );
      expect(find.text(MensajesNegocios.errorRed), findsOneWidget);
      expect(find.text(MensajesNegocios.busquedaInvalida), findsNothing);
      expect(find.text(MensajesNegocios.reintentar), findsOneWidget);
    });
    testWidgets('404 no permite reintentar', (tester) async {
      await mostrarPerfil(
        tester,
        NegociosServiceFalso(error: const ApiException(404, 'privado')),
      );
      expect(find.text(MensajesNegocios.noDisponible), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });
    testWidgets('id inválido muestra el negocio no disponible', (tester) async {
      var peticiones = 0;
      final servicio = NegociosService(
        api: ApiClient(
          client: MockClient((_) async {
            peticiones++;
            return http.Response('{}', 500);
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilNegocioPage(negocioId: 'a/b', negociosService: servicio),
        ),
      );
      await tester.pumpAndSettle();
      expect(peticiones, 0);
      expect(find.text(MensajesNegocios.noDisponible), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });
  });
}
