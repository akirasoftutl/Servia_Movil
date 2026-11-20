import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/auth/pages/login_page.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';

void main() {
  testWidgets('enlace público abre lista y permite volver al login', (
    tester,
  ) async {
    final fake = ListaServiceFalso()
      ..responder = (_) async => pagina([resumen('publico')]);
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(negociosService: fake)),
    );
    await tester.tap(find.text(MensajesNegocios.verSinSesion));
    await tester.pumpAndSettle();
    expect(find.byType(ListaNegociosPage), findsOneWidget);
    expect(find.text('Negocio publico'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });
  testWidgets('inicio muestra lista y el icono cierra sesión', (tester) async {
    var cierres = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onCerrarSesion: () => cierres++,
          negociosService: ListaServiceFalso()
            ..responder = (_) async => pagina([resumen('inicio')]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Servia'), findsOneWidget);
    expect(find.text('Negocio inicio'), findsOneWidget);
    expect(find.text('Nombre privado'), findsNothing);
    expect(find.text('correo@privado'), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    await tester.tap(find.byIcon(Icons.logout));
    expect(cierres, 1);
  });
}
