import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/features/notificaciones/data/aviso.dart';
import 'package:servia/features/notificaciones/data/servicio_push.dart';
import 'package:servia/features/notificaciones/pages/avisos_page.dart';

import '../../core/tema_de_la_app.dart';
import '../reservas/fakes.dart';
import 'fakes.dart';

/// Recordatorio de la cita (HU-C79, Móvil#65): lo manda la API (Servia_BE#112)
/// como aviso `RECORDATORIO_CITA` y como push FCM; aquí solo se muestra y abre.
const tipoRecordatorio = 'RECORDATORIO_CITA';
const tituloRecordatorio = 'Recordatorio de tu cita';
const cuerpoRecordatorio =
    'Recuerda tu cita SRV-7KQ2MX de Corte de cabello el 25/11/2026 a las 10:00.';

Aviso recordatorio({String id = 'rec1', bool leida = false}) => avisoPrueba(
  id: id,
  tipo: tipoRecordatorio,
  titulo: tituloRecordatorio,
  cuerpo: cuerpoRecordatorio,
  leida: leida,
  reservaId: 'r7',
);

({NotificacionesFalso notificaciones, ServicioPush push, MessagingFalso msg})
armar(WidgetTester tester, List<Aviso> avisos, {int noLeidas = 1}) {
  final notificaciones = NotificacionesFalso(
    paginas: {
      null: PaginaAvisos(items: avisos, noLeidas: noLeidas, siguiente: null),
    },
  );
  final msg = MessagingFalso();
  final push = ServicioPush(messaging: msg, notificaciones: notificaciones);
  addTearDown(push.dispose);
  return (notificaciones: notificaciones, push: push, msg: msg);
}

Widget pagina(
  NotificacionesFalso notificaciones,
  ServicioPush push, {
  ThemeData? tema,
  double escala = 1,
  List<String>? rutas,
}) => MaterialApp(
  theme: tema,
  navigatorKey: push.navigatorKey,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
    child: child!,
  ),
  home: AvisosPage(
    authService: SesionFalsa(),
    notificacionesService: notificaciones,
    push: push,
  ),
  onGenerateRoute: (ajustes) {
    rutas?.add(ajustes.name ?? '');
    return MaterialPageRoute<void>(
      settings: ajustes,
      builder: (_) => Scaffold(body: Text('Ruta ${ajustes.name}')),
    );
  },
);

void main() {
  group('bandeja', () {
    testWidgets('el recordatorio sale con su ícono de alarma y su texto', (
      tester,
    ) async {
      final a = armar(tester, [
        recordatorio(),
        avisoPrueba(id: 'otro', titulo: 'Reserva confirmada'),
      ]);
      await tester.pumpWidget(pagina(a.notificaciones, a.push));
      await tester.pumpAndSettle();

      expect(find.text(tituloRecordatorio), findsOneWidget);
      expect(find.text(cuerpoRecordatorio), findsOneWidget);
      expect(find.byIcon(Icons.alarm), findsOneWidget);
      // Los demás avisos llevan el ícono genérico: se distingue el recordatorio.
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    });

    testWidgets('un tipo desconocido no rompe la bandeja', (tester) async {
      final a = armar(tester, [
        recordatorio(),
        avisoPrueba(id: 'raro', tipo: 'TIPO_DEL_FUTURO', titulo: 'Algo nuevo'),
      ]);
      await tester.pumpWidget(pagina(a.notificaciones, a.push));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Algo nuevo'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      expect(find.byIcon(Icons.alarm), findsOneWidget);
    });

    testWidgets('sin leer: negritas, punto y cuenta en el globo', (
      tester,
    ) async {
      final a = armar(tester, [recordatorio()]);
      await tester.pumpWidget(pagina(a.notificaciones, a.push));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.text(tituloRecordatorio)).style?.fontWeight,
        FontWeight.w700,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == 'No leída',
        ),
        findsOneWidget,
      );
      expect(a.push.noLeidas.value, 1);
    });

    testWidgets('al tocarlo se marca leído y abre el detalle de la reserva', (
      tester,
    ) async {
      final a = armar(tester, [recordatorio()]);
      a.push.sincronizarNoLeidas(1);
      final rutas = <String>[];
      await tester.pumpWidget(pagina(a.notificaciones, a.push, rutas: rutas));
      await tester.pumpAndSettle();

      await tester.tap(find.text(tituloRecordatorio));
      await tester.pumpAndSettle();

      expect(a.notificaciones.marcadas, ['rec1']);
      expect(rutas, contains('/reservas/r7'));
      expect(a.push.noLeidas.value, 0);
    });
  });

  group('push del recordatorio', () {
    final mensaje = mensajePrueba(
      notificacionId: 'rec1',
      reservaId: 'r7',
      tipo: tipoRecordatorio,
      titulo: tituloRecordatorio,
      cuerpo: cuerpoRecordatorio,
    );

    testWidgets('con la app abierta suma al globo y «Ver» abre la reserva', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final a = armar(tester, [recordatorio()]);
      a.push.configurar();
      a.push.registrar('t');
      final rutas = <String>[];
      await tester.pumpWidget(pagina(a.notificaciones, a.push, rutas: rutas));
      await tester.pumpAndSettle();
      a.push.sincronizarNoLeidas(1);

      a.msg.mensajes.add(mensaje);
      await tester.pumpAndSettle();
      expect(a.push.noLeidas.value, 2);
      expect(find.text(tituloRecordatorio), findsWidgets);

      await tester.tap(find.text('Ver'));
      await tester.pumpAndSettle();
      expect(a.notificaciones.marcadas, ['rec1']);
      expect(rutas, contains('/reservas/r7'));
      expect(a.push.noLeidas.value, 1);
    });

    testWidgets('en segundo plano, tocar el push abre la reserva', (
      tester,
    ) async {
      final a = armar(tester, [recordatorio()]);
      a.push.configurar();
      a.push.registrar('t');
      a.push.sincronizarNoLeidas(1);
      final rutas = <String>[];
      await tester.pumpWidget(pagina(a.notificaciones, a.push, rutas: rutas));
      await tester.pumpAndSettle();

      a.msg.aperturas.add(mensaje);
      await tester.pumpAndSettle();

      expect(a.notificaciones.marcadas, ['rec1']);
      expect(rutas, contains('/reservas/r7'));
      expect(a.push.noLeidas.value, 0);
    });

    testWidgets('con la app cerrada, el mensaje inicial abre la reserva', (
      tester,
    ) async {
      final notificaciones = NotificacionesFalso();
      final push = ServicioPush(
        messaging: MessagingFalso(mensajeInicial: mensaje),
        notificaciones: notificaciones,
      );
      addTearDown(push.dispose);
      push.sincronizarNoLeidas(1);
      final rutas = <String>[];
      await tester.pumpWidget(pagina(notificaciones, push, rutas: rutas));
      await tester.pumpAndSettle();

      await push.cargarMensajeInicial();
      await push.procesarMensajePendiente('t');
      await tester.pumpAndSettle();

      expect(notificaciones.marcadas, ['rec1']);
      expect(rutas, contains('/reservas/r7'));
      expect(push.noLeidas.value, 0);
    });
  });

  group('diseño de Servia', () {
    for (final escala in [1.0, 2.0]) {
      testWidgets('los estilos salen del tema (texto a ${escala}x)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const SizedBox());
        final tema = temaDeLaApp(tester);
        final a = armar(tester, [
          recordatorio(),
          recordatorio(id: 'rec2', leida: true),
        ], noLeidas: 1);
        await tester.pumpWidget(
          pagina(a.notificaciones, a.push, tema: tema, escala: escala),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Tarjeta: la del tema (superficie, borde y radio de Servia).
        final tarjeta = tester.widget<Card>(find.byType(Card).first);
        expect(tarjeta.shape, isNull, reason: 'la forma sale del cardTheme');
        expect(tarjeta.color, isNull, reason: 'el color sale del cardTheme');
        expect(tema.cardTheme.color, ColoresServia.superficie);
        expect(tema.cardTheme.shape, isA<RoundedRectangleBorder>());

        // Título y cuerpo: estilos de la escala tipográfica del tema.
        final titulo = tester.widget<Text>(find.text(tituloRecordatorio).first);
        expect(titulo.style?.fontFamily, tema.textTheme.titleMedium?.fontFamily);
        expect(titulo.style?.fontSize, tema.textTheme.titleMedium?.fontSize);
        expect(titulo.style?.color, ColoresServia.texto);
        final cuerpo = tester.widget<Text>(find.text(cuerpoRecordatorio).first);
        expect(cuerpo.style?.fontSize, tema.textTheme.bodyMedium?.fontSize);
        expect(cuerpo.style?.color, ColoresServia.textoSuave);

        // Ícono: círculo de contenedor primario con el ícono sobre él.
        final icono = tester.widget<Icon>(find.byIcon(Icons.alarm).first);
        expect(icono.color, ColoresServia.enPrimarioContenedor);
        final circulo = tester.widget<Container>(
          find
              .ancestor(
                of: find.byIcon(Icons.alarm).first,
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (circulo.decoration as BoxDecoration).color,
          ColoresServia.primarioContenedor,
        );
        expect(circulo.constraints?.minWidth, Medidas.tactil);

        // Fondo de la pantalla: el del tema, no uno literal.
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, isNull);
        expect(tema.scaffoldBackgroundColor, ColoresServia.fondo);

        if (escala == 1.0) {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }
      });
    }
  });
}
