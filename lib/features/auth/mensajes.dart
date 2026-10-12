import 'package:firebase_auth/firebase_auth.dart';
import '../../core/network/api_exception.dart';

class MensajesAuth {
  MensajesAuth._();

  static const credencialesInvalidas = 'Correo o contraseña incorrectos';
  static const soloClientes =
      'Esta app es para clientes. Si tienes un negocio, entra desde el panel web';
  static const cuentaDesactivada =
      'Tu cuenta está desactivada. Ponte en contacto con soporte para más información.';
  static const errorSesion =
      'No se pudo verificar tu sesión. Vuelve a iniciar sesión.';
  static const errorRed =
      'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.';
  static const camposVacios = 'Ingresa tu correo y tu contraseña.';
  static const errorRegistroGeneral =
      'Ocurrió un error al crear la cuenta. Inténtalo de nuevo.';

  static String mensajeDeInicioSesion(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-credential':
        case 'invalid-email':
        case 'user-disabled':
        case 'operation-not-allowed':
          return credencialesInvalidas;
        case 'network-request-failed':
          return errorRed;
        case 'too-many-requests':
          return 'Demasiados intentos. Espera un momento y vuelve a intentar.';
      }
    }
    return errorRed;
  }

  static String mensajeDeRegistro(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 409) {
        return 'Ese correo ya tiene una cuenta';
      }
      if (error.statusCode == 400) {
        return error.mensaje;
      }
      if (error.statusCode >= 500) {
        return 'La API no está disponible. Intenta más tarde.';
      }
      return error.mensaje;
    }
    if (error is FirebaseAuthException) {
      if (error.code == 'network-request-failed') {
        return errorRed;
      }
    }
    return errorRegistroGeneral;
  }
}
