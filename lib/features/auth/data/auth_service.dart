import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

import '../../favoritos/data/favoritos_controlador.dart';
import '../../favoritos/data/favoritos_servicios_controlador.dart';
import '../../notificaciones/data/servicio_push.dart';

class AuthService {
  AuthService({this._push, FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _authInyectado = auth,
      _googleInyectado = googleSignIn;

  /// Solo las pruebas lo dan; la app usa `FirebaseAuth.instance`.
  final FirebaseAuth? _authInyectado;

  /// Igual que [_authInyectado]: las pruebas pueden inyectar su propio cliente
  /// de Google sin depender de los plugins nativos.
  final GoogleSignIn? _googleInyectado;

  /// Coordinador de FCM inyectado por `AuthGate` en la app real. Si el usuario
  /// negó el permiso, [ServicioPush.desactivar] no hace nada.
  final ServicioPush? _push;

  FirebaseAuth get _auth => _authInyectado ?? FirebaseAuth.instance;

  GoogleSignIn get _google => _googleInyectado ?? GoogleSignIn.instance;

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

  /// Abre el selector de cuenta de Google y cambia la sesión de Firebase al
  /// credencial devuelto. El perfil de cliente se crea en la API la primera vez
  /// (AuthGate y LoginPage lo piden cuando `/auth/yo` responde 401).
  Future<UserCredential> iniciarSesionConGoogle() async {
    late final GoogleSignInAccount cuenta;
    try {
      cuenta = await _google.authenticate();
    } on GoogleSignInException catch (error) {
      debugPrint(
        'GoogleSignIn: ${error.code} ${error.description ?? 'sin descripción'}',
      );
      if (error.code == GoogleSignInExceptionCode.canceled) {
        // En Android un SHA no registrado también llega como `canceled`.
        // Guardamos la descripción para poder avisar de la configuración.
        throw InicioGoogleCancelado(descripcion: error.description);
      }
      rethrow;
    }

    final idToken = cuenta.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const InicioGoogleSinToken();
    }

    final credencial = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credencial);
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
    // Google recuerda la cuenta aunque Firebase ya haya cerrado: sin esto, el
    // siguiente «Continuar con Google» entraría sin volver a pedirla.
    try {
      await _google.signOut();
    } catch (_) {
      // El plugin puede no estar configurado en pruebas o en otra plataforma.
    }
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

/// El usuario cerró el diálogo de Google a propósito. En Android Credential
/// Manager también usa este código para errores de configuración, por eso se
/// conserva la descripción que dio el plugin.
class InicioGoogleCancelado implements Exception {
  const InicioGoogleCancelado({this.descripcion});

  final String? descripcion;
}

/// Google no devolvió un ID token; no se puede crear la credencial de Firebase.
class InicioGoogleSinToken implements Exception {
  const InicioGoogleSinToken();
}
