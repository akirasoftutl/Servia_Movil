import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/auth/data/auth_service.dart';
import 'package:servia/features/auth/data/perfil.dart';
import 'package:servia/features/auth/data/perfil_service.dart';
import 'package:servia/features/auth/data/registro_cliente_service.dart';
import 'package:servia/features/auth/mensajes.dart';
import 'package:servia/features/auth/pages/auth_gate.dart';
import 'package:servia/features/auth/pages/login_page.dart';
import 'package:servia/features/auth/pages/register_page.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/perfil/pages/mi_perfil_page.dart';

import 'features/perfil/fakes_perfil.dart';

class UsuarioFalso extends Fake implements User {
  @override
  String? get displayName => 'Ana Pérez';

  @override
  String? get email => 'ana@test.com';

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'token-cliente';
}

class SesionFalsa extends AuthService {
  final eventos = StreamController<User?>.broadcast();
  User? usuario;
  int inicios = 0;
  int cierres = 0;

  @override
  Stream<User?> get cambiosDeSesion async* {
    yield usuario;
    yield* eventos.stream;
  }

  @override
  User? get usuarioActual => usuario;

  @override
  Future<void> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    inicios++;
    usuario = UsuarioFalso();
    eventos.add(usuario);
  }

  @override
  Future<void> cerrarSesion() async {
    cierres++;
    usuario = null;
    eventos.add(null);
  }
}

class PerfilFalso extends PerfilService {
  PerfilFalso({this.tipo = 'cliente', this.error});
  final String tipo;
  final Object? error;
  int consultas = 0;

  @override
  Future<Perfil> obtenerYo(String token) async {
    consultas++;
    expect(token, 'token-cliente');
    if (error != null) throw error!;
    return Perfil(
      uid: 'cliente',
      nombre: 'Ana Pérez',
      correo: 'ana@test.com',
      tipo: tipo,
    );
  }
}

class RegistroFalso extends RegistroClienteService {
  RegistroFalso({this.error});
  final Object? error;
  int registros = 0;

  @override
  Future<RegistroClienteResponse> registrarCliente(
    RegistroClienteRequest request,
  ) async {
    registros++;
    expect(request.correo, 'ana@test.com');
    if (error != null) throw error!;
    return const RegistroClienteResponse(
      id: 'cliente',
      nombre: 'Ana Pérez',
      correo: 'ana@test.com',
      telefono: '4771234567',
      tipo: 'cliente',
    );
  }
}

Future<void> abrirRegistro(
  WidgetTester tester,
  SesionFalsa sesion,
  PerfilFalso perfil,
  RegistroFalso registro,
) async {
  tester.view.physicalSize = const Size(1000, 1500);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(sesion.eventos.close);
  await tester.pumpWidget(
    MaterialApp(
      home: AuthGate(
        authService: sesion,
        perfilService: perfil,
        registroClienteService: registro,
        perfilClienteService: PerfilClienteFalso(<String>[]),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Sin sesión AuthGate muestra el inicio: el login se abre desde «Perfil».
  expect(find.byType(HomePage), findsOneWidget);
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
  expect(find.byType(LoginPage), findsOneWidget);
  await tester.tap(find.text('Regístrate'));
  await tester.pumpAndSettle();
  expect(find.byType(RegisterPage), findsOneWidget);
  expect(find.byType(AuthGate, skipOffstage: false), findsOneWidget);
}

Future<void> registrar(WidgetTester tester) async {
  for (final (i, texto) in [
    'Ana Pérez',
    '4771234567',
    'ana@test.com',
    '12345678',
  ].indexed) {
    await tester.enterText(find.byType(TextFormField).at(i), texto);
  }
  await tester.ensureVisible(find.text('Crear cuenta'));
  await tester.tap(find.text('Crear cuenta'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'registro → inicio de AuthGate → cerrar sesión → login → inicio',
    (tester) async {
      final sesion = SesionFalsa();
      final perfil = PerfilFalso();
      final registro = RegistroFalso();
      await abrirRegistro(tester, sesion, perfil, registro);
      await registrar(tester);
      expect(find.text('Tu cuenta se creó correctamente'), findsOneWidget);
      expect(find.byType(RegisterPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(HomePage),
          matching: find.byType(AuthGate),
        ),
        findsOneWidget,
      );
      expect(perfil.consultas, 1);
      expect(registro.registros, 1);

      // Con sesión, «Perfil» abre MiPerfilPage; cerrar sesión es una fila
      // al final de su lista y devuelve al inicio como invitado.
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.byType(MiPerfilPage), findsOneWidget);
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
      expect(sesion.cierres, 1);

      // Sin sesión hay que abrir el login de nuevo desde «Perfil».
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
      await tester.enterText(find.byType(TextField).at(0), 'ana@test.com');
      await tester.enterText(find.byType(TextField).at(1), '12345678');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(HomePage),
          matching: find.byType(AuthGate),
        ),
        findsOneWidget,
      );
      expect(perfil.consultas, 2);
      expect(sesion.inicios, 2);
    },
  );

  testWidgets('registro fallido conserva el error y permite reintentar', (
    tester,
  ) async {
    final sesion = SesionFalsa();
    final perfil = PerfilFalso();
    await abrirRegistro(
      tester,
      sesion,
      perfil,
      RegistroFalso(error: ApiException(409, 'duplicado')),
    );
    await registrar(tester);
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.text('Ese correo ya tiene una cuenta'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Crear cuenta'),
          )
          .onPressed,
      isNotNull,
    );
    expect(perfil.consultas, 0);
    expect(sesion.inicios, 0);
  });

  testWidgets('el enlace de volver al login conserva AuthGate', (tester) async {
    await abrirRegistro(tester, SesionFalsa(), PerfilFalso(), RegistroFalso());
    await tester.ensureVisible(find.text('Inicia sesión'));
    await tester.tap(find.text('Inicia sesión'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(LoginPage),
        matching: find.byType(AuthGate),
      ),
      findsOneWidget,
    );
  });

  for (final desactivada in [false, true]) {
    testWidgets(
      'AuthGate rechaza tras registro la cuenta ${desactivada ? 'desactivada' : 'de negocio'}',
      (tester) async {
        final sesion = SesionFalsa();
        final perfil = PerfilFalso(
          tipo: 'negocio',
          error: desactivada ? ApiException(403, 'desactivada') : null,
        );
        await abrirRegistro(tester, sesion, perfil, RegistroFalso());
        await registrar(tester);
        // Tras el rechazo AuthGate vuelve al inicio como invitado; el motivo
        // se ve al abrir el login desde la pestaña «Perfil».
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(MiPerfilPage), findsNothing);
        await tester.tap(find.text('Perfil'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(
          find.text(
            desactivada
                ? MensajesAuth.cuentaDesactivada
                : MensajesAuth.soloClientes,
          ),
          findsOneWidget,
        );
        expect(sesion.cierres, 1);
      },
    );
  }
}
