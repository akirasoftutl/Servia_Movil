import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/ayuda/data/reporte.dart';
import 'package:servia/features/ayuda/pages/reportar_problema_page.dart';

import '../reservas/fakes.dart';
import 'fakes_ayuda.dart';
import '../../core/tema_de_la_app.dart';

const asuntoValido = 'No carga mi reserva';
const descripcionValida = 'La pantalla se queda en blanco al abrir mi reserva.';
const ayudaAsunto = 'El asunto debe tener entre 5 y 100 caracteres.';
const ayudaDescripcion =
    'La descripción debe tener entre 20 y 1000 caracteres.';
const exito = 'Tu reporte se envió correctamente.';
const mensaje429 = 'Enviaste demasiados reportes; inténtalo más tarde.';

Finder get campoAsunto => find.byKey(const Key('campo-asunto'));
Finder get campoDescripcion => find.byKey(const Key('campo-descripcion'));
Finder get botonEnviar => find.byKey(const Key('boton-enviar-reporte'));

Future<SesionFalsa> abrir(
  WidgetTester tester,
  SoporteFalso soporte, {
  SesionFalsa? sesion,
}) async {
  final auth = sesion ?? SesionFalsa();
  // El formulario y «Mis reportes enviados» caben juntos en este viewport.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: ReportarProblemaPage(authService: auth, soporteService: soporte),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

Future<void> escribir(WidgetTester tester, String asunto, String desc) async {
  await tester.enterText(campoAsunto, asunto);
  await tester.enterText(campoDescripcion, desc);
  await tester.pump();
}

Future<void> enviar(WidgetTester tester) async {
  await tester.ensureVisible(botonEnviar);
  await tester.tap(botonEnviar);
  await tester.pumpAndSettle();
}

String textoDe(WidgetTester tester, String texto) =>
    tester.widget<Text>(find.text(texto)).data!;

void main() {
  group('formulario y validación rápida (C3)', () {
    testWidgets('muestra los campos, los textos de ayuda y los contadores', (
      tester,
    ) async {
      await abrir(tester, SoporteFalso());
      expect(find.text('Reportar un problema'), findsWidgets);
      expect(find.text('Asunto'), findsOneWidget);
      expect(find.text('Descripción'), findsOneWidget);
      expect(find.text(ayudaAsunto), findsOneWidget);
      expect(find.text(ayudaDescripcion), findsOneWidget);
      expect(find.text('0/100'), findsOneWidget);
      expect(find.text('0/1000'), findsOneWidget);
    });

    testWidgets('los contadores cuentan sin los espacios de los extremos', (
      tester,
    ) async {
      await abrir(tester, SoporteFalso());
      await escribir(tester, '   Hola   ', '  $descripcionValida ');
      expect(find.text('4/100'), findsOneWidget);
      expect(find.text('${descripcionValida.length}/1000'), findsOneWidget);
    });

    testWidgets('asunto de 4 caracteres: no se envía, no llama a la API y el '
        'texto de ayuda se pone en rojo', (tester) async {
      final soporte = SoporteFalso();
      await abrir(tester, soporte);
      await escribir(tester, 'Hola', descripcionValida);
      await enviar(tester);
      expect(soporte.enviados, isEmpty);
      final rojo = tester.widget<Text>(find.text(ayudaAsunto)).style?.color;
      expect(
        rojo,
        Theme.of(tester.element(find.text(ayudaAsunto))).colorScheme.error,
      );
      // La descripción válida no se marca.
      expect(find.text(ayudaDescripcion), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(ayudaDescripcion)).style?.color,
        isNot(
          Theme.of(tester.element(find.text(ayudaAsunto))).colorScheme.error,
        ),
      );
    });

    testWidgets('descripción de 19 caracteres: no se envía', (tester) async {
      final soporte = SoporteFalso();
      await abrir(tester, soporte);
      await escribir(tester, asuntoValido, 'a' * 19);
      await enviar(tester);
      expect(soporte.enviados, isEmpty);
      expect(
        tester.widget<Text>(find.text(ayudaDescripcion)).style?.color,
        Theme.of(tester.element(find.text(ayudaDescripcion))).colorScheme.error,
      );
    });

    testWidgets('los espacios de los extremos no cuentan', (tester) async {
      final soporte = SoporteFalso();
      await abrir(tester, soporte);
      await escribir(tester, '   Hola   ', '  ${'a' * 19}  ');
      await enviar(tester);
      expect(soporte.enviados, isEmpty);
    });

    testWidgets('campos vacíos: no se envía', (tester) async {
      final soporte = SoporteFalso();
      await abrir(tester, soporte);
      await enviar(tester);
      expect(soporte.enviados, isEmpty);
    });

    testWidgets('101 caracteres de asunto o 1001 de descripción: no se envía', (
      tester,
    ) async {
      final soporte = SoporteFalso();
      await abrir(tester, soporte);
      await escribir(tester, 'a' * 101, descripcionValida);
      await enviar(tester);
      expect(soporte.enviados, isEmpty);
      await escribir(tester, asuntoValido, 'a' * 1001);
      await enviar(tester);
      expect(soporte.enviados, isEmpty);
    });

    testWidgets(
      'los topes exactos (5, 100, 20 y 1000) sí se envían, recortados',
      (tester) async {
        final soporte = SoporteFalso();
        await abrir(tester, soporte);
        await escribir(tester, ' ${'a' * 5} ', 'b' * 20);
        await enviar(tester);
        await escribir(tester, 'a' * 100, ' ${'b' * 1000} ');
        await enviar(tester);
        expect(soporte.enviados.length, 2);
        expect(soporte.enviados[0].asunto, 'a' * 5);
        expect(soporte.enviados[0].descripcion, 'b' * 20);
        expect(soporte.enviados[1].asunto, 'a' * 100);
        expect(soporte.enviados[1].descripcion, 'b' * 1000);
      },
    );
  });

  group('envío correcto (C4)', () {
    testWidgets('avisa, limpia el formulario y suma el reporte a la lista', (
      tester,
    ) async {
      final soporte = SoporteFalso();
      final auth = await abrir(tester, soporte);
      expect(find.text('Todavía no has enviado reportes'), findsOneWidget);
      await escribir(tester, '  $asuntoValido  ', descripcionValida);
      await enviar(tester);

      expect(soporte.enviados.length, 1);
      expect(soporte.enviados.single.token, 'token');
      expect(soporte.enviados.single.asunto, asuntoValido);
      expect(soporte.enviados.single.descripcion, descripcionValida);
      expect(auth.cierres, 0);

      expect(find.text(exito), findsOneWidget);
      expect(tester.widget<TextFormField>(campoAsunto).controller!.text, '');
      expect(
        tester.widget<TextFormField>(campoDescripcion).controller!.text,
        '',
      );
      expect(find.text('0/100'), findsOneWidget);
      // Sin marcar el formulario vacío como error tras limpiarlo.
      expect(
        tester.widget<Text>(find.text(ayudaAsunto)).style?.color,
        isNot(
          Theme.of(tester.element(find.text(ayudaAsunto))).colorScheme.error,
        ),
      );

      expect(find.text('Mis reportes enviados'), findsOneWidget);
      expect(find.text('Todavía no has enviado reportes'), findsNothing);
      expect(find.text(asuntoValido), findsOneWidget);
      expect(find.text('Abierto'), findsOneWidget);
      // 2026-11-24 20:05 UTC = 14:05 en la Ciudad de México (UTC-6).
      expect(find.textContaining('24 de noviembre de 2026'), findsOneWidget);
      expect(find.textContaining('14:05'), findsOneWidget);
    });

    testWidgets('el más reciente queda arriba', (tester) async {
      final soporte = SoporteFalso(
        existentes: [reporte('Reporte viejo', id: 'v')],
      );
      await abrir(tester, soporte);
      await escribir(tester, asuntoValido, descripcionValida);
      await enviar(tester);
      final arriba = tester.getTopLeft(find.text(asuntoValido)).dy;
      final abajo = tester.getTopLeft(find.text('Reporte viejo')).dy;
      expect(arriba, lessThan(abajo));
    });

    testWidgets('mientras envía el botón queda deshabilitado y no duplica', (
      tester,
    ) async {
      final soporte = SoporteFalso()..esperaEnvio = Completer<void>();
      await abrir(tester, soporte);
      await escribir(tester, asuntoValido, descripcionValida);
      await tester.ensureVisible(botonEnviar);
      await tester.tap(botonEnviar);
      await tester.pump();
      expect(tester.widget<ElevatedButton>(botonEnviar).onPressed, isNull);
      expect(find.text('Enviando...'), findsOneWidget);
      await tester.tap(botonEnviar, warnIfMissed: false);
      await tester.pump();
      expect(soporte.enviados.length, 1);

      soporte.esperaEnvio!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(botonEnviar).onPressed, isNotNull);
      expect(find.text(exito), findsOneWidget);
      expect(soporte.enviados.length, 1);
    });

    testWidgets('si el 201 llega sin cuerpo legible, vuelve a pedir la lista', (
      tester,
    ) async {
      final soporte = _SinCuerpo();
      await abrir(tester, soporte);
      await escribir(tester, asuntoValido, descripcionValida);
      await enviar(tester);
      expect(find.text(exito), findsOneWidget);
      expect(soporte.listados, 2);
      expect(find.text(asuntoValido), findsOneWidget);
    });

    testWidgets('el aviso de éxito se quita al empezar otro reporte', (
      tester,
    ) async {
      await abrir(tester, SoporteFalso());
      await escribir(tester, asuntoValido, descripcionValida);
      await enviar(tester);
      expect(find.text(exito), findsOneWidget);
      await tester.enterText(campoAsunto, 'Otro');
      await tester.pump();
      expect(find.text(exito), findsNothing);
    });
  });

  group('Mis reportes enviados (C4, C5)', () {
    testWidgets('carga con el token del cliente y muestra asunto, fecha y '
        '«Abierto»', (tester) async {
      final soporte = SoporteFalso(
        existentes: [
          reporte('Primero', id: 'a'),
          reporte(
            'Segundo',
            id: 'b',
            creadaEn: DateTime.utc(2026, 11, 20, 3, 30),
          ),
        ],
      );
      await abrir(tester, soporte);
      expect(soporte.tokens, ['token']);
      expect(soporte.listados, 1);
      expect(find.text('Primero'), findsOneWidget);
      expect(find.text('Segundo'), findsOneWidget);
      expect(find.text('Abierto'), findsNWidgets(2));
      // 2026-11-20 03:30 UTC = 19 de noviembre, 21:30 en México.
      expect(find.textContaining('19 de noviembre de 2026'), findsOneWidget);
      expect(find.textContaining('21:30'), findsOneWidget);
    });

    testWidgets('vacío: «Todavía no has enviado reportes»', (tester) async {
      await abrir(tester, SoporteFalso());
      expect(find.text('Todavía no has enviado reportes'), findsOneWidget);
    });

    testWidgets('error al cargar: mensaje en español y «Reintentar» que '
        'recupera la lista', (tester) async {
      final soporte = SoporteFalso(existentes: [reporte('Guardado')])
        ..fallosAlListar.add(const ApiException(500, 'x'));
      await abrir(tester, soporte);
      expect(
        find.text('No pudimos cargar tus reportes. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Guardado'), findsNothing);
      await tester.ensureVisible(find.text('Reintentar'));
      await tester.pump();
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Guardado'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('sin red al cargar: mismo mensaje, sin diálogos', (
      tester,
    ) async {
      final soporte = SoporteFalso()
        ..fallosAlListar.add(const SocketException('sin red'));
      await abrir(tester, soporte);
      expect(
        find.text('No pudimos cargar tus reportes. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
      'sesión vencida (401) al cargar: avisa y no ofrece reintentar',
      (tester) async {
        final soporte = SoporteFalso()
          ..fallosAlListar.add(const ApiException(401, 'x'));
        await abrir(tester, soporte);
        expect(
          find.text('Tu sesión venció. Vuelve a iniciar sesión.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsNothing);
      },
    );

    testWidgets('si falla la lista el formulario sigue disponible', (
      tester,
    ) async {
      final soporte = SoporteFalso()
        ..fallosAlListar.add(const ApiException(500, 'x'));
      await abrir(tester, soporte);
      await escribir(tester, asuntoValido, descripcionValida);
      await enviar(tester);
      expect(soporte.enviados.length, 1);
      expect(find.text(exito), findsOneWidget);
    });
  });

  group('errores al enviar (C6)', () {
    Future<void> falla(
      WidgetTester tester,
      Object error,
      String mensaje,
    ) async {
      final soporte = SoporteFalso()..fallosAlEnviar.add(error);
      final auth = await abrir(tester, soporte);
      await escribir(tester, asuntoValido, descripcionValida);
      await enviar(tester);
      expect(find.text(mensaje), findsOneWidget);
      expect(find.text(exito), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      // No se pierde lo escrito y se puede reintentar.
      expect(
        tester.widget<TextFormField>(campoAsunto).controller!.text,
        asuntoValido,
      );
      expect(
        tester.widget<TextFormField>(campoDescripcion).controller!.text,
        descripcionValida,
      );
      expect(tester.widget<ElevatedButton>(botonEnviar).onPressed, isNotNull);
      expect(auth.cierres, 0);
      await enviar(tester);
      expect(soporte.enviados.length, 2);
      expect(find.text(exito), findsOneWidget);
      expect(find.text(mensaje), findsNothing);
    }

    testWidgets('sin red', (tester) async {
      await falla(
        tester,
        const SocketException('sin red'),
        'No pudimos enviar tu reporte. Revisa tu conexión e intenta de nuevo.',
      );
    });

    testWidgets('tiempo agotado', (tester) async {
      await falla(
        tester,
        TimeoutException('lento'),
        'No pudimos enviar tu reporte. Revisa tu conexión e intenta de nuevo.',
      );
    });

    testWidgets('cliente HTTP caído', (tester) async {
      await falla(
        tester,
        http.ClientException('cerrado'),
        'No pudimos enviar tu reporte. Revisa tu conexión e intenta de nuevo.',
      );
    });

    testWidgets('429: el mensaje de la API', (tester) async {
      await falla(tester, const ApiException(429, mensaje429), mensaje429);
    });

    testWidgets('400: el mensaje de la API', (tester) async {
      const m =
          'La descripción debe tener entre 20 y 1000 caracteres sin espacios en los extremos.';
      await falla(tester, const ApiException(400, m), m);
    });

    testWidgets('500: la API no está disponible', (tester) async {
      await falla(
        tester,
        const ApiException(
          500,
          'La API no está disponible. Intenta más tarde.',
        ),
        'La API no está disponible. Intenta más tarde.',
      );
    });

    testWidgets('el error se quita al volver a escribir', (tester) async {
      final soporte = SoporteFalso()
        ..fallosAlEnviar.add(const ApiException(429, mensaje429));
      await abrir(tester, soporte);
      await escribir(tester, asuntoValido, descripcionValida);
      await enviar(tester);
      expect(find.text(mensaje429), findsOneWidget);
      await tester.enterText(campoAsunto, '$asuntoValido!');
      await tester.pump();
      expect(find.text(mensaje429), findsNothing);
    });

    testWidgets('401 al enviar: cierra la sesión como el resto de la app', (
      tester,
    ) async {
      final soporte = SoporteFalso()
        ..fallosAlEnviar.add(const ApiException(401, 'x'));
      final auth = await abrir(tester, soporte);
      await escribir(tester, asuntoValido, descripcionValida);
      await enviar(tester);
      expect(auth.cierres, 1);
      expect(
        find.text('Tu sesión venció. Vuelve a iniciar sesión.'),
        findsOneWidget,
      );
    });

    testWidgets('sin sesión no llama a la API', (tester) async {
      final soporte = SoporteFalso();
      await abrir(tester, soporte, sesion: SesionFalsa(conSesion: false));
      await escribir(tester, asuntoValido, descripcionValida);
      await enviar(tester);
      expect(soporte.enviados, isEmpty);
      expect(
        find.text('Tu sesión venció. Vuelve a iniciar sesión.'),
        findsWidgets,
      );
    });
  });

  group('diseño (C7)', () {
    testWidgets('usa el tema de la app: botón principal y áreas táctiles', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final tema = temaDeLaApp(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: ReportarProblemaPage(
            authService: SesionFalsa(),
            soporteService: SoporteFalso(existentes: [reporte('Uno')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}

/// API que responde 201 sin cuerpo legible.
class _SinCuerpo extends SoporteFalso {
  @override
  Future<Reporte?> enviar(
    String token, {
    required String asunto,
    required String descripcion,
  }) async {
    enviados.add((token: token, asunto: asunto, descripcion: descripcion));
    reportes.insert(0, reporte(asunto));
    return null;
  }
}
