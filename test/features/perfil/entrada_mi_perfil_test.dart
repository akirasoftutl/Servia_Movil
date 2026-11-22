import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/auth/data/perfil.dart';
import 'package:servia/features/auth/data/perfil_service.dart';
import 'package:servia/features/auth/mensajes.dart';
import 'package:servia/features/auth/pages/auth_gate.dart';
import 'package:servia/features/auth/pages/login_page.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/perfil/pages/mi_perfil_page.dart';

import '../negocios/fakes.dart';
import 'fakes_perfil.dart';

class PerfilGateFalso extends PerfilService {
  PerfilGateFalso(this.tipo);
  final String tipo;

  @override
  Future<Perfil> obtenerYo(String token) async =>
      Perfil(uid: 'u', nombre: 'Ana Pérez', correo: 'ana@test.com', tipo: tipo);
}

/// El acceso a «Mi perfil» ya no es un tooltip ni una ruta aparte: es la
/// pestaña «Perfil» de la barra inferior del inicio.
Future<void> abrirPestanaPerfil(WidgetTester tester) async {
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('desde el inicio se abre «Mi perfil» y se vuelve a la lista', (
    tester,
  ) async {
    final eventos = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onCerrarSesion: () {},
          negociosService: ListaServiceFalso()
            ..responder = (_) async => pagina([resumen('inicio')]),
          authService: SesionPerfilFalsa(eventos),
          perfilClienteService: PerfilClienteFalso(eventos),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Negocio inicio'), findsOneWidget);

    await abrirPestanaPerfil(tester);
    expect(find.byType(MiPerfilPage), findsOneWidget);
    expect(find.text('ana@test.com'), findsOneWidget);

    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(MiPerfilPage), findsNothing);
    expect(find.text('Negocio inicio'), findsOneWidget);
  });

  testWidgets(
    'con sesión de cliente el inicio ofrece «Mi perfil» y cerrar sesión sigue igual',
    (tester) async {
      final eventos = <String>[];
      final sesion = SesionPerfilFalsa(eventos);
      addTearDown(sesion.cambios.close);
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            authService: sesion,
            perfilService: PerfilGateFalso('cliente'),
            perfilClienteService: PerfilClienteFalso(eventos),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);

      await abrirPestanaPerfil(tester);
      expect(find.byType(MiPerfilPage), findsOneWidget);
      expect(find.text('4771234567'), findsOneWidget);

      // Cerrar sesión es una fila al final de la lista de MiPerfilPage.
      await tester.scrollUntilVisible(
        find.text('Cerrar sesión'),
        200,
        scrollable: find.descendant(
          of: find.byType(MiPerfilPage),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(MiPerfilPage), findsNothing);

      // Sin sesión, la pestaña «Perfil» abre el login.
      await abrirPestanaPerfil(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    },
  );

  testWidgets('sin sesión no hay acceso a «Mi perfil»', (tester) async {
    final eventos = <String>[];
    final sesion = SesionPerfilFalsa(eventos)..usuario = null;
    addTearDown(sesion.cambios.close);
    await tester.pumpWidget(MaterialApp(home: AuthGate(authService: sesion)));
    await tester.pumpAndSettle();

    // AuthGate muestra el inicio como invitado; el perfil pide login.
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(MiPerfilPage), findsNothing);
    expect(find.text('Cerrar sesión'), findsNothing);

    await abrirPestanaPerfil(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(MiPerfilPage), findsNothing);
  });

  testWidgets('una cuenta que no es de cliente no llega a «Mi perfil»', (
    tester,
  ) async {
    final eventos = <String>[];
    final sesion = SesionPerfilFalsa(eventos);
    addTearDown(sesion.cambios.close);
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authService: sesion,
          perfilService: PerfilGateFalso('negocio'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(MiPerfilPage), findsNothing);

    await abrirPestanaPerfil(tester);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text(MensajesAuth.soloClientes), findsOneWidget);
  });
}
