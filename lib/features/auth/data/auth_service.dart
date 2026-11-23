import 'package:firebase_auth/firebase_auth.dart';

import '../../notificaciones/data/servicio_push.dart';

class AuthService {
  AuthService({this._push});

  /// Coordinador de FCM inyectado por `AuthGate` en la app real. Si el usuario
  /// negó el permiso, [ServicioPush.desactivar] no hace nada.
  final ServicioPush? _push;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  User? get usuarioActual => _auth.currentUser;

  Future<void> iniciarSesion({
    required String correo,
    required String contrasena,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
  }

  Future<void> enviarCorreoRestablecimiento(String correo) {
    return _auth.sendPasswordResetEmail(email: correo.trim());
  }

  /// Reautentica con la contraseña actual antes de cambiarla, como exige
  /// Firebase para las operaciones sensibles.
  Future<void> cambiarContrasena({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) async {
    final usuario = _auth.currentUser;
    final correo = usuario?.email;
    if (usuario == null || correo == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No hay una sesión con correo electrónico.',
      );
    }
    final credencial = EmailAuthProvider.credential(
      email: correo,
      password: contrasenaActual,
    );
    await usuario.reauthenticateWithCredential(credencial);
    await usuario.updatePassword(contrasenaNueva);
  }

  /// Da de baja el token FCM en la API antes de cerrar la sesión de Firebase:
  /// ese teléfono deja de recibir push de esta cuenta (MVP-28).
  Future<void> cerrarSesion() async {
    final usuario = _auth.currentUser;
    final push = _push;
    if (usuario != null && push != null) {
      try {
        final token = await usuario.getIdToken();
        if (token != null) await push.desactivar(token);
      } catch (_) {
        // Un fallo de red no debe impedir cerrar la sesión.
      }
    }
    await _auth.signOut();
  }
}
