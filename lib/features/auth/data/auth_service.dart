import 'package:firebase_auth/firebase_auth.dart';

import '../../favoritos/data/favoritos_controlador.dart';
import '../../favoritos/data/favoritos_servicios_controlador.dart';
import '../../notificaciones/data/servicio_push.dart';

class AuthService {
  AuthService({this._push, FirebaseAuth? auth}) : _authInyectado = auth;

  /// Solo las pruebas lo dan; la app usa `FirebaseAuth.instance`.
  final FirebaseAuth? _authInyectado;

  /// Coordinador de FCM inyectado por `AuthGate` en la app real. Si el usuario
  /// negó el permiso, [ServicioPush.desactivar] no hace nada.
  final ServicioPush? _push;

  FirebaseAuth get _auth => _authInyectado ?? FirebaseAuth.instance;

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

  /// Reautentica con la contraseña actual, como exige Firebase para las
  /// operaciones sensibles (cambiar la contraseña, eliminar la cuenta).
  Future<void> reautenticar(String contrasena) async {
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
      password: contrasena,
    );
    await usuario.reauthenticateWithCredential(credencial);
  }

  Future<void> cambiarContrasena({
    required String contrasenaActual,
    required String contrasenaNueva,
  }) async {
    await reautenticar(contrasenaActual);
    await _auth.currentUser!.updatePassword(contrasenaNueva);
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
    // Los favoritos son de la cuenta: no deben verse con otra (RN-46).
    FavoritosControlador.instancia.limpiar();
    FavoritosServiciosControlador.instancia.limpiar();
  }

  /// Cierra la sesión local después de que la API eliminó la cuenta (HU-C14).
  /// El usuario de Authentication ya no existe, así que si Firebase se queja
  /// al cerrar se ignora: lo importante es que la app quede sin sesión ni
  /// datos de la cuenta (favoritos, token de push).
  Future<void> cerrarSesionTrasEliminar() async {
    try {
      await cerrarSesion();
    } catch (_) {
      try {
        await _auth.signOut();
      } catch (_) {
        // Sin usuario en el servidor no hay nada más que cerrar.
      }
      FavoritosControlador.instancia.limpiar();
    }
  }
}
