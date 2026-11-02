import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/auth/data/perfil.dart';
import 'package:servia/features/auth/data/perfil_service.dart';
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

    await tester.tap(find.byTooltip('Mi perfil'));
    await tester.pumpAndSettle();
    expect(find.byType(MiPerfilPage), findsOneWidget);
    expect(find.text('ana@test.com'), findsOneWidget);

    await tester.pageBack();
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

      await tester.tap(find.byTooltip('Mi perfil'));
      await tester.pumpAndSettle();
      expect(find.byType(MiPerfilPage), findsOneWidget);
      expect(find.text('4771234567'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
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
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byTooltip('Mi perfil'), findsNothing);
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
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byTooltip('Mi perfil'), findsNothing);
  });
}
