import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/notificaciones/data/aviso.dart';
import 'package:servia/features/notificaciones/data/servicio_push.dart';
import 'package:servia/features/notificaciones/mensajes.dart';
import 'package:servia/features/notificaciones/pages/avisos_page.dart';
import '../reservas/fakes.dart';
import 'fakes.dart';

Widget appCon({
  required NotificacionesFalso notificaciones,
  required ServicioPush push,
  Route<dynamic>? Function(RouteSettings)? onGenerateRoute,
}) => MaterialApp(
  home: AvisosPage(
    authService: SesionFalsa(),
    notificacionesService: notificaciones,
    push: push,
  ),
  onGenerateRoute: onGenerateRoute,
);

void main() {
  testWidgets('muestra título, cuerpo y fecha; primero el más nuevo', (
    tester,
  ) async {
    final notificaciones = NotificacionesFalso(
      paginas: {
        null: PaginaAvisos(
          items: [
            avisoPrueba(
              id: 'viejo',
              titulo: 'Reserva cancelada',
              cuerpo: 'Tu reserva fue cancelada.',
              leida: true,
              creadaEn: DateTime.utc(2026, 11, 20, 10),
            ),
            avisoPrueba(
              id: 'nuevo',
              titulo: 'Reserva confirmada',
              cuerpo: 'Tu reserva quedó confirmada.',
              creadaEn: DateTime.utc(2026, 11, 22, 10, 5),
            ),
          ],
          noLeidas: 1,
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
      appCon(notificaciones: notificaciones, push: push),
    );
    await tester.pumpAndSettle();

    expect(find.text(MensajesNotificaciones.titulo), findsOneWidget);
    expect(find.text('Reserva confirmada'), findsOneWidget);
    expect(find.text('Reserva cancelada'), findsOneWidget);
    expect(find.textContaining('22 de noviembre de 2026'), findsOneWidget);
    expect(find.textContaining('20 de noviembre de 2026'), findsOneWidget);

    // El más nuevo aparece primero en el árbol.
    final titulos = find.textContaining('Reserva ', skipOffstage: false);
    expect(
      (titulos.evaluate().first.widget as Text).data,
      'Reserva confirmada',
    );
    expect(push.noLeidas.value, 1);
  });

  testWidgets('no leídos en negrita con punto; leídos sin punto', (tester) async {
    final notificaciones = NotificacionesFalso(
      paginas: {
        null: PaginaAvisos(
          items: [
            avisoPrueba(id: 'nueva', titulo: 'Sin leer', leida: false),
            avisoPrueba(
              id: 'vieja',
              titulo: 'Ya leída',
              leida: true,
              creadaEn: DateTime.utc(2026, 11, 20),
            ),
          ],
          noLeidas: 1,
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
      appCon(notificaciones: notificaciones, push: push),
    );
    await tester.pumpAndSettle();

    expect(
      (tester.widget<Text>(find.text('Sin leer')).style?.fontWeight),
      FontWeight.w700,
    );
    expect(
      (tester.widget<Text>(find.text('Ya leída')).style?.fontWeight),
      FontWeight.w500,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color ==
                const Color(0xFF7C3AED),
      ),
      findsOneWidget,
    );
  });

  testWidgets('estado vacío', (tester) async {
    final notificaciones = NotificacionesFalso();
    final push = ServicioPush(
      messaging: MessagingFalso(),
      notificaciones: notificaciones,
    );
    addTearDown(push.dispose);
    await tester.pumpWidget(
      appCon(notificaciones: notificaciones, push: push),
    );
    await tester.pumpAndSettle();

    expect(find.text(MensajesNotificaciones.sinAvisos), findsOneWidget);
    expect(find.text('Reserva confirmada'), findsNothing);
  });

  testWidgets('error y reintento', (tester) async {
    final notificaciones = NotificacionesFalso(
      paginas: {
        null: PaginaAvisos(
          items: [avisoPrueba()],
          noLeidas: 1,
          siguiente: null,
        ),
      },
    );
    final push = ServicioPush(
      messaging: MessagingFalso(),
      notificaciones: notificaciones,
    );
    addTearDown(push.dispose);
    // Primer intento falla; el reintento devuelve la lista.
    notificaciones.error = StateError('sin red');
    await tester.pumpWidget(
      appCon(notificaciones: notificaciones, push: push),
    );
    await tester.pumpAndSettle();
    expect(find.text(MensajesNotificaciones.errorCarga), findsOneWidget);

    notificaciones.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Reserva confirmada'), findsOneWidget);
    expect(find.text(MensajesNotificaciones.errorCarga), findsNothing);
  });

  testWidgets('paginación con «Cargar más» y al llegar al final', (tester) async {
    final notificaciones = NotificacionesFalso(
      paginas: {
        null: PaginaAvisos(
          items: [avisoPrueba(id: 'a1')],
          noLeidas: 2,
          siguiente: 'cursor-2',
        ),
        'cursor-2': PaginaAvisos(
          items: [
            avisoPrueba(
              id: 'a2',
              titulo: 'Segunda reserva',
              creadaEn: DateTime.utc(2026, 11, 18),
            ),
          ],
          noLeidas: 2,
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
      appCon(notificaciones: notificaciones, push: push),
    );
    await tester.pumpAndSettle();

    expect(find.text('Segunda reserva'), findsNothing);
    expect(find.text(MensajesNotificaciones.cargarMas), findsOneWidget);
    await tester.tap(find.text(MensajesNotificaciones.cargarMas));
    await tester.pumpAndSettle();
    expect(find.text('Segunda reserva'), findsOneWidget);
    expect(find.text(MensajesNotificaciones.cargarMas), findsNothing);
  });

  testWidgets('al tocar un aviso marca leída y abre el detalle de reserva', (
    tester,
  ) async {
    final notificaciones = NotificacionesFalso(
      paginas: {
        null: PaginaAvisos(
          items: [avisoPrueba(id: 'a1', reservaId: 'r1')],
          noLeidas: 1,
          siguiente: null,
        ),
      },
    );
    final push = ServicioPush(
      messaging: MessagingFalso(),
      notificaciones: notificaciones,
    );
    addTearDown(push.dispose);
    push.sincronizarNoLeidas(1);

    final rutas = <String>[];
    await tester.pumpWidget(
      appCon(
        notificaciones: notificaciones,
        push: push,
        onGenerateRoute: (ajustes) {
          rutas.add(ajustes.name ?? '');
          return MaterialPageRoute<void>(
            settings: ajustes,
            builder: (_) => Scaffold(body: Text('Ruta ${ajustes.name}')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reserva confirmada'));
    await tester.pumpAndSettle();

    expect(notificaciones.marcadas, ['a1']);
    expect(rutas, contains('/reservas/r1'));
    expect(find.text('Ruta /reservas/r1'), findsOneWidget);
    expect(push.noLeidas.value, 0);
  });

  testWidgets('tocar un aviso ya leído no baja el globo ni vuelve a marcarlo', (
    tester,
  ) async {
    final notificaciones = NotificacionesFalso(
      paginas: {
        null: PaginaAvisos(
          items: [avisoPrueba(id: 'a1', leida: true, reservaId: 'r1')],
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
    push.sincronizarNoLeidas(3);

    final rutas = <String>[];
    await tester.pumpWidget(
      appCon(
        notificaciones: notificaciones,
        push: push,
        onGenerateRoute: (ajustes) {
          rutas.add(ajustes.name ?? '');
          return MaterialPageRoute<void>(
            settings: ajustes,
            builder: (_) => Scaffold(body: Text('Ruta ${ajustes.name}')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reserva confirmada'));
    await tester.pumpAndSettle();

    expect(push.noLeidas.value, 3);
    expect(notificaciones.marcadas, isEmpty);
    expect(rutas, contains('/reservas/r1'));
  });
}
