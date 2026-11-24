import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/api_exception.dart';
import 'data/auth_service.dart';

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
  static const correoRestablecimientoEnviado =
      'Si el correo está registrado, te enviamos un enlace para crear una contraseña nueva.';
  static const contrasenaActualIncorrecta =
      'La contraseña actual no es correcta.';
  static const contrasenaActualizada = 'Tu contraseña se actualizó.';
  static const errorCambioContrasena =
      'No se pudo cambiar la contraseña. Inténtalo de nuevo.';
  static const errorRecuperacion =
      'No se pudo enviar el correo. Inténtalo de nuevo.';
  static const googleCancelado = 'Se canceló el acceso con Google.';
  static const googleNoConfigurado =
      'Google no está configurado en la app. Revisa la configuración de Firebase.';
  static const googleSha =
      'Google no pudo verificar esta app. Registra la huella SHA de Android en Firebase y vuelve a intentar.';
  static const googleCorreoOcupado =
      'Ese correo ya tiene una cuenta. Entra con el método que usaste al registrarte.';

  static String mensajeDeInicioSesion(Object error) {
    if (error is InicioGoogleCancelado) {
      return _esConfiguracionGoogle(error.descripcion)
          ? googleSha
          : googleCancelado;
    }
    if (error is InicioGoogleSinToken) return errorSesion;

    if (error is GoogleSignInException) {
      switch (error.code) {
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          return googleNoConfigurado;
        case GoogleSignInExceptionCode.canceled:
          return _esConfiguracionGoogle(error.description)
              ? googleSha
              : googleCancelado;
        default:
          return errorRed;
      }
    }

    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'user-not-found':
        case 'invalid-credential':
        case 'invalid-email':
        case 'user-disabled':
        case 'operation-not-allowed':
          return credencialesInvalidas;
        case 'account-exists-with-different-credential':
          return googleCorreoOcupado;
        case 'network-request-failed':
          return errorRed;
        case 'too-many-requests':
          return 'Demasiados intentos. Espera un momento y vuelve a intentar.';
      }
    }
    return errorRed;
  }

  /// Credential Manager devuelve `canceled` también cuando el SHA del APK no
  /// está registrado; la descripción dice `Account reauth failed` o algo
  /// parecido. Una cancelación real no trae ese texto.
  static bool _esConfiguracionGoogle(String? descripcion) {
    final texto = (descripcion ?? '').toLowerCase();
    return texto.contains('reauth') ||
        texto.contains('developer console') ||
        texto.contains('not set up correctly') ||
        texto.contains('configuration');
  }

  static String mensajeDeRecuperacion(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'network-request-failed':
          return errorRed;
        case 'too-many-requests':
          return 'Demasiados intentos. Espera un momento y vuelve a intentar.';
      }
    }
    return errorRecuperacion;
  }

  static String mensajeDeCambioContrasena(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return contrasenaActualIncorrecta;
        case 'weak-password':
          return 'La contraseña debe tener al menos 8 caracteres.';
        case 'network-request-failed':
          return errorRed;
        case 'requires-recent-login':
        case 'user-not-found':
        case 'user-disabled':
        case 'user-token-expired':
        case 'invalid-user-token':
          return errorSesion;
      }
    }
    return errorCambioContrasena;
  }

  static String mensajeDeRegistro(Object error) {
    if (error is TimeoutException) return errorRed;
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
