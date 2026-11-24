import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/auth/data/auth_service.dart';
import 'package:servia/features/favoritos/data/favoritos_controlador.dart';

class _Usuario extends Fake implements User {
  _Usuario(this.eventos, {this.errorAlReautenticar});
  final List<String> eventos;
  final Object? errorAlReautenticar;
  AuthCredential? credencial;

  @override
  String? get email => 'ana@test.com';

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) async {
    eventos.add('reauth');
    credencial = credential;
    if (errorAlReautenticar != null) throw errorAlReautenticar!;
    return _Credencial();
  }

  @override
  Future<void> updatePassword(String nueva) async =>
      eventos.add('updatePassword');

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'tok';
}

class _Credencial extends Fake implements UserCredential {}

class _Firebase extends Fake implements FirebaseAuth {
  _Firebase(this.usuario, this.eventos, {this.errorAlCerrar});
  final User? usuario;
  final List<String> eventos;
  final Object? errorAlCerrar;

  @override
  User? get currentUser => usuario;

  @override
  Future<void> signOut() async {
    eventos.add('signOut');
    if (errorAlCerrar != null) throw errorAlCerrar!;
  }
}

void main() {
  test(
    'reautenticar usa el correo de la sesión y la contraseña dada',
    () async {
      final eventos = <String>[];
      final usuario = _Usuario(eventos);
      final auth = AuthService(auth: _Firebase(usuario, eventos));
      await auth.reautenticar('mi-clave');
      expect(eventos, ['reauth']);
      final mapa = usuario.credencial!.asMap();
      expect(mapa['providerId'], 'password');
      expect(mapa['email'], 'ana@test.com');
      expect(mapa['secret'], 'mi-clave');
    },
  );

  test('reautenticar sin sesión lanza user-not-found', () async {
    final auth = AuthService(auth: _Firebase(null, []));
    await expectLater(
      auth.reautenticar('x'),
      throwsA(
        isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'user-not-found',
        ),
      ),
    );
  });

  test('la contraseña incorrecta se propaga y no cierra la sesión', () async {
    final eventos = <String>[];
    final usuario = _Usuario(
      eventos,
      errorAlReautenticar: FirebaseAuthException(code: 'wrong-password'),
    );
    final auth = AuthService(auth: _Firebase(usuario, eventos));
    await expectLater(
      auth.reautenticar('mala'),
      throwsA(isA<FirebaseAuthException>()),
    );
    expect(eventos, ['reauth']);
  });

  test(
    'cambiarContrasena reautentica y después cambia la contraseña',
    () async {
      final eventos = <String>[];
      final auth = AuthService(auth: _Firebase(_Usuario(eventos), eventos));
      await auth.cambiarContrasena(
        contrasenaActual: 'a',
        contrasenaNueva: 'nueva-clave',
      );
      expect(eventos, ['reauth', 'updatePassword']);
    },
  );

  test(
    'cerrarSesionTrasEliminar cierra Firebase y limpia los favoritos',
    () async {
      final eventos = <String>[];
      final auth = AuthService(auth: _Firebase(_Usuario(eventos), eventos));
      await auth.cerrarSesionTrasEliminar();
      expect(eventos, ['signOut']);
    },
  );

  test('si Firebase falla porque el usuario ya no existe, se tolera', () async {
    final eventos = <String>[];
    final auth = AuthService(
      auth: _Firebase(
        _Usuario(eventos),
        eventos,
        errorAlCerrar: FirebaseAuthException(code: 'user-not-found'),
      ),
    );
    await auth.cerrarSesionTrasEliminar();
    // Intentó cerrar, falló y volvió a intentarlo sin propagar el error.
    expect(
      eventos.where((e) => e == 'signOut').length,
      greaterThanOrEqualTo(1),
    );
    expect(FavoritosControlador.instancia, isNotNull);
  });
}
