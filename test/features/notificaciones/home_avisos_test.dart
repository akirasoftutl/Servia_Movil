import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/notificaciones/data/aviso.dart';
import 'package:servia/features/notificaciones/data/servicio_push.dart';
import 'package:servia/features/notificaciones/mensajes.dart';
import 'package:servia/features/notificaciones/pages/avisos_page.dart';
import 'package:servia/features/notificaciones/rutas_notificaciones.dart';

import '../negocios/fakes.dart';
import '../reservas/fakes.dart';
import 'fakes.dart';

Widget appCon({
  required GlobalKey<NavigatorState> navigatorKey,
  required NotificacionesFalso notificaciones,
  required ServicioPush push,
}) => MaterialApp(
  navigatorKey: navigatorKey,
  home: HomePage(
    onCerrarSesion: () {},
    negociosService: ListaServiceFalso()
      ..responder = (_) async => pagina([resumen('inicio')]),
    authService: SesionFalsa(),
    reservasService: ReservasFalso(),
    notificacionesService: notificaciones,
    push: push,
  ),
  onGenerateRoute: (ajustes) {
    final ruta = generarRutaNotificaciones(ajustes, push: push);
    if (ruta != null) return ruta;
    return MaterialPageRoute<void>(
      settings: ajustes,
      builder: (_) => Scaffold(body: Text('Ruta ${ajustes.name}')),
    );
  },
);

void main() {
  testWidgets('la campana muestra el globo con no leídos y abre «Avisos»', (
    tester,
  ) async {
    final notificaciones = NotificacionesFalso(
      paginas: {
        null: PaginaAvisos(
          items: [avisoPrueba()],
          noLeidas: 3,
          siguiente: null,
        ),
      },
    );
    final push = ServicioPush(
      messaging: MessagingFalso(),
      notificaciones: notificaciones,
    );
    addTearDown(push.dispose);
    await tester.pumpWidget(
      appCon(
        navigatorKey: GlobalKey<NavigatorState>(),
        notificaciones: notificaciones,
        push: push,
      ),
    );
    await tester.pumpAndSettle();
    // La campana vive con los accesos rápidos de la pestaña «Perfil».
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.byTooltip(MensajesNotificaciones.campana));
    await tester.pumpAndSettle();

    expect(find.byType(AvisosPage), findsOneWidget);
  });

  testWidgets('sin no leídos no se pinta el globo', (tester) async {
    final push = ServicioPush(
      messaging: MessagingFalso(),
      notificaciones: NotificacionesFalso(),
    );
    addTearDown(push.dispose);
    await tester.pumpWidget(
      appCon(
        navigatorKey: GlobalKey<NavigatorState>(),
        notificaciones: NotificacionesFalso(),
        push: push,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsNothing);
  });

  testWidgets('push en primer plano muestra SnackBar y «Ver» marca leída', (
    tester,
  ) async {
    final notificaciones = NotificacionesFalso(
      paginas: {
        null: PaginaAvisos(
          items: [avisoPrueba()],
          noLeidas: 1,
          siguiente: null,
        ),
      },
    );
    final mensajeria = MessagingFalso();
    final navigatorKey = GlobalKey<NavigatorState>();
    final push = ServicioPush(
      messaging: mensajeria,
      notificaciones: notificaciones,
      navigatorKey: navigatorKey,
    );
    addTearDown(push.dispose);
    push.configurar();
    await push.registrar('token-api');
    await tester.pumpWidget(
      appCon(
        navigatorKey: navigatorKey,
        notificaciones: notificaciones,
        push: push,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    mensajeria.mensajes.add(
      mensajePrueba(
        notificacionId: 'a1',
        reservaId: 'r1',
        titulo: 'Tu reserva fue confirmada',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tu reserva fue confirmada'), findsOneWidget);
    expect(find.text(MensajesNotificaciones.ver), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text(MensajesNotificaciones.ver));
    await tester.pumpAndSettle();

    expect(notificaciones.marcadas, ['a1']);
    expect(find.text('Ruta /reservas/r1'), findsOneWidget);
    expect(push.noLeidas.value, 1);
  });

  testWidgets('abrir desde segundo plano marca leída y navega al detalle', (
    tester,
  ) async {
    final notificaciones = NotificacionesFalso();
    final mensajeria = MessagingFalso();
    final navigatorKey = GlobalKey<NavigatorState>();
    final push = ServicioPush(
      messaging: mensajeria,
      notificaciones: notificaciones,
      navigatorKey: navigatorKey,
    );
    addTearDown(push.dispose);
    push.configurar();
    await push.registrar('token-api');
    await tester.pumpWidget(
      appCon(
        navigatorKey: navigatorKey,
        notificaciones: notificaciones,
        push: push,
      ),
    );
    await tester.pumpAndSettle();

    mensajeria.aperturas.add(
      mensajePrueba(notificacionId: 'a7', reservaId: 'r9'),
    );
    await tester.pumpAndSettle();

    expect(notificaciones.marcadas, ['a7']);
    expect(find.text('Ruta /reservas/r9'), findsOneWidget);
  });

  testWidgets('mensaje inicial abre el detalle cuando ya hay sesión', (
    tester,
  ) async {
    final notificaciones = NotificacionesFalso();
    final navigatorKey = GlobalKey<NavigatorState>();
    final push = ServicioPush(
      messaging: MessagingFalso(
        mensajeInicial: mensajePrueba(notificacionId: 'a8', reservaId: 'r4'),
      ),
      notificaciones: notificaciones,
      navigatorKey: navigatorKey,
    );
    addTearDown(push.dispose);
    await push.cargarMensajeInicial();
    await tester.pumpWidget(
      appCon(
        navigatorKey: navigatorKey,
        notificaciones: notificaciones,
        push: push,
      ),
    );
    await tester.pumpAndSettle();

    await push.procesarMensajePendiente('token-api');
    await tester.pumpAndSettle();

    expect(notificaciones.marcadas, ['a8']);
    expect(find.text('Ruta /reservas/r4'), findsOneWidget);
  });
}
