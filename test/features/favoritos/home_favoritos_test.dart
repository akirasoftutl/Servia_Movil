import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/favoritos/mensajes.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/notificaciones/data/servicio_push.dart';

import '../negocios/fakes.dart';
import '../notificaciones/fakes.dart';
import '../reservas/fakes.dart';

Future<List<String>> montarInicio(
  WidgetTester tester, {
  required bool conSesion,
}) async {
  final rutas = <String>[];
  final notificaciones = NotificacionesFalso();
  final push = ServicioPush(
    messaging: MessagingFalso(),
    notificaciones: notificaciones,
  );
  addTearDown(push.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        onCerrarSesion: () {},
        negociosService: ListaServiceFalso()
          ..responder = (_) async => pagina([resumen('inicio')]),
        authService: SesionFalsa(conSesion: conSesion),
        reservasService: ReservasFalso(),
        notificacionesService: notificaciones,
        push: push,
      ),
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
  return rutas;
}

void main() {
  testWidgets('con sesión, el ícono «Mis favoritos» abre /favoritos', (
    tester,
  ) async {
    final rutas = await montarInicio(tester, conSesion: true);
    // En el rediseño los accesos rápidos están en la pestaña «Perfil».
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(find.byTooltip(MensajesFavoritos.titulo));
    await tester.pumpAndSettle();

    expect(rutas, contains('/favoritos'));
    expect(find.text('Ruta /favoritos'), findsOneWidget);
  });

  testWidgets('sin sesión no hay ícono de favoritos', (tester) async {
    await montarInicio(tester, conSesion: false);
    expect(find.byTooltip(MensajesFavoritos.titulo), findsNothing);
  });
}
