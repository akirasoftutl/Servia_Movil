import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:servia/features/auth/data/auth_service.dart';
import 'package:servia/features/auth/data/perfil.dart';
import 'package:servia/features/auth/mensajes.dart';
import 'package:servia/features/auth/pages/login_page.dart';

class AuthServiceFalso extends AuthService {
  AuthServiceFalso({this.tipoError});

  final String? tipoError;

  @override
  Future<void> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    switch (tipoError) {
      case 'credenciales':
        throw FirebaseAuthException(
          code: 'wrong-password',
          message: 'Contraseña incorrecta.',
        );
      case 'red':
        throw FirebaseAuthException(
          code: 'network-request-failed',
          message: 'Sin conexión.',
        );
      default:
        return;
    }
  }
}

void main() {
  group('MensajesAuth.mensajeDeInicioSesion', () {
    test('credenciales inválidas producen el mensaje genérico', () {
      for (final code in const [
        'wrong-password',
        'user-not-found',
        'invalid-credential',
        'invalid-email',
        'user-disabled',
      ]) {
        expect(
          MensajesAuth.mensajeDeInicioSesion(
            FirebaseAuthException(code: code, message: code),
          ),
          MensajesAuth.credencialesInvalidas,
          reason: 'el código $code debe dar el mensaje genérico',
        );
      }
    });

    test('errores desconocidos producen el mensaje de red', () {
      expect(MensajesAuth.mensajeDeInicioSesion(Exception('x')),
          MensajesAuth.errorRed);
      expect(
        MensajesAuth.mensajeDeInicioSesion(
          FirebaseAuthException(
            code: 'algo-desconocido',
            message: 'x',
          ),
        ),
        MensajesAuth.errorRed,
      );
    });
  });

  group('Perfil', () {
    test('una cuenta de negocio no es cliente', () {
      const perfil = Perfil(
        uid: 'uid-1',
        nombre: 'Mi Negocio',
        correo: 'negocio@test.com',
        tipo: 'negocio',
      );
      expect(perfil.esCliente, isFalse);
    });

    test('una cuenta de cliente se reconoce como cliente', () {
      const perfil = Perfil(
        uid: 'uid-1',
        nombre: 'Juan',
        correo: 'juan@test.com',
        tipo: 'cliente',
      );
      expect(perfil.esCliente, isTrue);
    });
  });

  group('LoginPage', () {
    testWidgets('muestra "Correo o contraseña incorrectos" con credenciales malas',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(authService: AuthServiceFalso(tipoError: 'credenciales')),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'cliente@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'contraseña-mala');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text(MensajesAuth.credencialesInvalidas), findsOneWidget);
    });

    testWidgets('no dice cuál campo falló', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(authService: AuthServiceFalso(tipoError: 'credenciales')),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'cliente@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'contraseña-mala');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('usuario no existe', findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining('contraseña incorrecta', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('pide los campos si están vacíos', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: LoginPage(authService: AuthServiceFalso())),
      );

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text(MensajesAuth.camposVacios), findsOneWidget);
    });

    testWidgets('muestra el mensaje inicial enviado por AuthGate',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(
            authService: AuthServiceFalso(),
            mensajeInicial: MensajesAuth.soloClientes,
          ),
        ),
      );

      expect(find.text(MensajesAuth.soloClientes), findsOneWidget);
    });
  });
}