import '../../core/network/api_exception.dart';

/// Textos de Ayuda y de Reportar un problema (HU-C114 a HU-C117, T17).
class MensajesAyuda {
  MensajesAyuda._();

  // Entrada y pantalla de Ayuda.
  static const tooltipAyuda = 'Ayuda';
  static const tituloAyuda = 'Ayuda';
  static const preguntasFrecuentes = 'Preguntas frecuentes';
  static const botonReportar = 'Reportar un problema';
  static const introReportar =
      '¿Algo no funciona como esperabas? Cuéntanos y lo revisamos.';

  // Formulario.
  static const tituloReportar = 'Reportar un problema';
  static const etiquetaAsunto = 'Asunto';
  static const etiquetaDescripcion = 'Descripción';
  static const ayudaAsunto = 'El asunto debe tener entre 5 y 100 caracteres.';
  static const ayudaDescripcion =
      'La descripción debe tener entre 20 y 1000 caracteres.';
  static const enviar = 'Enviar reporte';
  static const enviando = 'Enviando...';
  static const exito = 'Tu reporte se envió correctamente.';

  // Mis reportes enviados.
  static const misReportes = 'Mis reportes enviados';
  static const sinReportes = 'Todavía no has enviado reportes';
  static const cargandoReportes = 'Cargando tus reportes...';
  static const etiquetaAbierto = 'Abierto';

  // Errores.
  static const errorEnvioRed =
      'No pudimos enviar tu reporte. Revisa tu conexión e intenta de nuevo.';
  static const errorEnvio = 'No pudimos enviar tu reporte. Intenta de nuevo.';
  static const errorLista = 'No pudimos cargar tus reportes. Intenta de nuevo.';
  static const datosInvalidos =
      'Revisa el asunto y la descripción e inténtalo de nuevo.';
  static const limiteReportes =
      'Enviaste demasiados reportes; inténtalo más tarde.';
  static const sesionVencida = 'Tu sesión venció. Vuelve a iniciar sesión.';
  static const cuentaNoPermitida =
      'Tu cuenta no puede enviar reportes. Ponte en contacto con soporte.';
  static const errorApi = 'La API no está disponible. Intenta más tarde.';

  /// Mensaje de [error] al enviar. Los [ApiException] del servicio ya traen
  /// el texto en español; lo demás (sin red, tiempo agotado) es de conexión.
  static String mensajeDeEnvio(Object error) {
    if (error is ApiException) {
      return error.statusCode == 401 ? sesionVencida : error.mensaje;
    }
    if (error is FormatException) return errorEnvio;
    return errorEnvioRed;
  }

  /// Mensaje de [error] al cargar la lista de reportes.
  static String mensajeDeLista(Object error) =>
      puedeReintentarLista(error) ? errorLista : sesionVencida;

  /// Con la sesión vencida no se ofrece reintentar: hay que iniciar sesión.
  static bool puedeReintentarLista(Object error) =>
      error is! ApiException || error.statusCode != 401;
}
