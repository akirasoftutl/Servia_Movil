import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/auth/data/auth_service.dart';
import 'package:servia/features/auth/mensajes.dart';
import 'package:servia/features/auth/pages/cambiar_contrasena_page.dart';
import 'package:servia/features/auth/pages/recuperar_contrasena_page.dart';

class AuthServiceFalso extends AuthService {
  String? correoEnviado;
  Object? errorAlEnviar;
  String? actualRecibida;
  String? nuevaRecibida;
  Object? errorAlCambiar;
  int cambios = 0;

  @override
  Future<void> enviarCorreoRestablecimiento(String correo) async {
    correoEnviado = correo;
    if (errorAlEnviar != null) throw errorAlEnviar!;
  }

  @override
  Future<void> cambiarContrasena({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) async {
    cambios++;
    actualRecibida = contrasenaActual;
    nuevaRecibida = contrasenaNueva;
    if (errorAlCambiar != null) throw errorAlCambiar!;
  }
}

Widget appCambio(AuthServiceFalso auth) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CambiarContrasenaPage(authService: auth),
            ),
          ),
          child: const Text('Abrir'),
        ),
      ),
    ),
  ),
);

Future<void> abrirCambio(WidgetTester tester, AuthServiceFalso auth) async {
  await tester.pumpWidget(appCambio(auth));
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> llenarCambio(
  WidgetTester tester, {
  String actual = 'actual123',
  String nueva = 'nueva12345',
  String? confirmacion,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), actual);
  await tester.enterText(find.byType(TextFormField).at(1), nueva);
  await tester.enterText(
    find.byType(TextFormField).at(2),
    confirmacion ?? nueva,
  );
}

Future<void> enviarCambio(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Cambiar contraseña'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'recuperación: envía el enlace y muestra siempre el mismo aviso',
    (tester) async {
      final auth = AuthServiceFalso();
      await tester.pumpWidget(
        MaterialApp(home: RecuperarContrasenaPage(authService: auth)),
      );
      await tester.enterText(find.byType(TextFormField), 'ana@test.com');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();

      expect(auth.correoEnviado, 'ana@test.com');
      expect(
        find.text(MensajesAuth.correoRestablecimientoEnviado),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'recuperación: user-not-found no revela que la cuenta no existe',
    (tester) async {
      final auth = AuthServiceFalso()
        ..errorAlEnviar = FirebaseAuthException(code: 'user-not-found');
      await tester.pumpWidget(
        MaterialApp(home: RecuperarContrasenaPage(authService: auth)),
      );
      await tester.enterText(find.byType(TextFormField), 'noexiste@test.com');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();

      expect(
        find.text(MensajesAuth.correoRestablecimientoEnviado),
        findsOneWidget,
      );
      expect(find.textContaining('user-not-found'), findsNothing);
    },
  );

  testWidgets('cambio: reautentica con la actual y actualiza la nueva', (
    tester,
  ) async {
    final auth = AuthServiceFalso();
    await abrirCambio(tester, auth);
    await llenarCambio(tester);
    await enviarCambio(tester);

    expect(auth.cambios, 1);
    expect(auth.actualRecibida, 'actual123');
    expect(auth.nuevaRecibida, 'nueva12345');
    expect(find.byType(CambiarContrasenaPage), findsNothing);
    expect(find.text(MensajesAuth.contrasenaActualizada), findsOneWidget);
  });

  testWidgets('cambio: contraseña actual incorrecta muestra el aviso', (
    tester,
  ) async {
    final auth = AuthServiceFalso()
      ..errorAlCambiar = FirebaseAuthException(code: 'wrong-password');
    await abrirCambio(tester, auth);
    await llenarCambio(tester);
    await enviarCambio(tester);

    expect(find.text(MensajesAuth.contrasenaActualIncorrecta), findsOneWidget);
    expect(find.byType(CambiarContrasenaPage), findsOneWidget);
    expect(find.text(MensajesAuth.contrasenaActualizada), findsNothing);
  });

  testWidgets('cambio: exige mínimo 8 caracteres y confirmación igual', (
    tester,
  ) async {
    final auth = AuthServiceFalso();
    await abrirCambio(tester, auth);
    await llenarCambio(tester, nueva: 'corta', confirmacion: 'otra');
    await enviarCambio(tester);

    expect(
      find.text('La contraseña debe tener al menos 8 caracteres.'),
      findsOneWidget,
    );
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(auth.cambios, 0);
  });
}
