import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/auth/data/auth_service.dart';
import 'package:servia/features/auth/data/perfil.dart';
import 'package:servia/features/auth/data/perfil_service.dart';
import 'package:servia/features/auth/data/registro_cliente_service.dart';
import 'package:servia/features/auth/mensajes.dart';
import 'package:servia/features/auth/pages/auth_gate.dart';
import 'package:servia/features/auth/pages/login_page.dart';
import 'package:servia/features/auth/pages/register_page.dart';

class UsuarioFalso extends Fake implements User {
  @override
  String? get displayName => 'Ana Pérez';

  @override
  String? get email => 'ana@test.com';

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token';
}

class SesionFalsa extends AuthService {
  final usuario = UsuarioFalso();

  @override
  User? get usuarioActual => usuario;

  @override
  Stream<User?> get cambiosDeSesion => Stream.value(usuario);
}

class PerfilSinRespuesta extends PerfilService {
  @override
  Future<Perfil> obtenerYo(String token) async =>
      throw TimeoutException('perfil');
}

class RegistroSinRespuesta extends RegistroClienteService {
  @override
  Future<RegistroClienteResponse> registrarCliente(
    RegistroClienteRequest request,
  ) async {
    throw TimeoutException('registro');
  }
}

class LoginSinRespuesta extends AuthService {
  @override
  Future<void> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    throw TimeoutException('login');
  }
}

void main() {
  for (final metodo in ['GET', 'POST']) {
    test(
      '$metodo agota el límite inyectado y conserva TimeoutException',
      () async {
        final api = ApiClient(
          client: MockClient((_) async {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            return http.Response('tarde', 200);
          }),
          limite: const Duration(milliseconds: 1),
        );
        await expectLater(
          metodo == 'GET' ? api.get('/prueba') : api.post('/prueba'),
          throwsA(isA<TimeoutException>()),
        );
      },
    );
    test('$metodo conserva respuesta, token y cuerpo', () async {
      final api = ApiClient(
        client: MockClient((request) async {
          expect(request.method, metodo);
          expect(request.url.path, '/prueba');
          expect(request.headers['Authorization'], 'Bearer token');
          if (metodo == 'POST') expect(request.body, '{"nombre":"Ana"}');
          return http.Response('{"ok":true}', 201);
        }),
      );
      expect(ApiClient.tiempoLimite, const Duration(seconds: 15));
      final respuesta = metodo == 'GET'
          ? await api.get('/prueba', token: 'token')
          : await api.post('/prueba', token: 'token', body: '{"nombre":"Ana"}');
      expect(respuesta.statusCode, 201);
      expect(respuesta.body, '{"ok":true}');
    });
  }

  test('registro traduce timeout sin alterar los demás errores', () {
    expect(
      MensajesAuth.mensajeDeRegistro(TimeoutException('x')),
      MensajesAuth.errorRed,
    );
    expect(
      MensajesAuth.mensajeDeRegistro(Exception('x')),
      MensajesAuth.errorRegistroGeneral,
    );
    expect(
      MensajesAuth.mensajeDeRegistro(ApiException(409, 'x')),
      'Ese correo ya tiene una cuenta',
    );
    expect(
      MensajesAuth.mensajeDeRegistro(ApiException(400, 'Datos inválidos')),
      'Datos inválidos',
    );
    expect(
      MensajesAuth.mensajeDeRegistro(ApiException(503, 'x')),
      'La API no está disponible. Intenta más tarde.',
    );
    expect(
      MensajesAuth.mensajeDeRegistro(
        FirebaseAuthException(code: 'network-request-failed'),
      ),
      MensajesAuth.errorRed,
    );
  });

  testWidgets('AuthGate sale de carga tras timeout y ofrece reintentar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthGate(
          authService: SesionFalsa(),
          perfilService: PerfilSinRespuesta(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(MensajesAuth.errorRed), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Reintentar'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('login sale de carga tras timeout y permite reintentar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginPage(authService: LoginSinRespuesta())),
    );
    await tester.enterText(find.byType(TextField).at(0), 'ana@test.com');
    await tester.enterText(find.byType(TextField).at(1), '12345678');
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text(MensajesAuth.errorRed), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('registro sale de carga tras timeout y permite reintentar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(registroClienteService: RegistroSinRespuesta()),
      ),
    );
    final campos = find.byType(TextFormField);
    for (final (i, texto) in [
      'Ana Pérez',
      '4771234567',
      'ana@test.com',
      '12345678',
    ].indexed) {
      await tester.enterText(campos.at(i), texto);
    }
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    expect(find.text(MensajesAuth.errorRed), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
  });
}
