import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
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

  Future<void> cerrarSesion() => _auth.signOut();
}
