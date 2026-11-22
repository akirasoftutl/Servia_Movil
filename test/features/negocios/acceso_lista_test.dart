import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/auth/pages/login_page.dart';
import 'package:servia/features/home/pages/home_page.dart';

import '../perfil/fakes_perfil.dart';
import 'fakes.dart';

void main() {
  testWidgets('inicio público muestra la lista y permite abrir el login', (
    tester,
  ) async {
    final fake = ListaServiceFalso()
      ..responder = (_) async => pagina([resumen('publico')]);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => HomePage(
            onCerrarSesion: () {},
            authService: SesionPerfilFalsa([])..usuario = null,
            negociosService: fake,
            onSolicitarLogin: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LoginPage()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ubicación actual'), findsOneWidget);
    expect(find.text('Negocio publico'), findsWidgets);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Ubicación actual'), findsOneWidget);
    expect(find.text('Negocio publico'), findsWidgets);
  });
  testWidgets('inicio muestra lista y el perfil cierra la sesión', (
    tester,
  ) async {
    final sesion = SesionPerfilFalsa([]);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onCerrarSesion: () {},
          authService: sesion,
          perfilClienteService: PerfilClienteFalso([]),
          negociosService: ListaServiceFalso()
            ..responder = (_) async => pagina([resumen('inicio')]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ubicación actual'), findsOneWidget);
    expect(find.text('Negocio inicio'), findsWidgets);
    expect(find.text('Nombre privado'), findsNothing);
    expect(find.text('correo@privado'), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    final cerrarSesion = find.text('Cerrar sesión', skipOffstage: false);
    expect(cerrarSesion, findsOneWidget);
    await tester.ensureVisible(cerrarSesion);
    await tester.pumpAndSettle();
    await tester.tap(cerrarSesion);
    await tester.pumpAndSettle();
    expect(sesion.usuarioActual, isNull);
  });
}
