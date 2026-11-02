import '../../core/network/api_exception.dart';

class MensajesNegocios {
  MensajesNegocios._();

  static const errorRed =
      'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.';
  static const noDisponible = 'Este negocio no está disponible.';
  static const paginaNoExiste = 'Esta página no existe.';
  static const errorApi = 'La API no está disponible. Intenta más tarde.';
  static const errorCarga =
      'Ocurrió un error al cargar el negocio. Inténtalo de nuevo.';
  static const reintentar = 'Reintentar';
  static const descanso = 'Descanso';
  static const aceptaReservas = 'Acepta reservas';
  static const noAceptaReservas = 'No acepta reservas por ahora';
  static const tituloPerfil = 'Perfil del negocio';
  static const buscar = 'Buscar negocios o servicios';
  static const limpiar = 'Limpiar búsqueda';
  static const todas = 'Todas';
  static const sinResultados = 'No encontramos negocios con esa búsqueda';
  static const busquedaInvalida =
      'Revisa la búsqueda y la categoría e inténtalo de nuevo.';
  static const tituloLista = 'Negocios';
  static const listaVacia = 'Todavía no hay negocios disponibles';
  static const verSinSesion = 'Ver negocios sin iniciar sesión';
  static const horario = 'Horario de atención';

  static String mensajeDeError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 400) return busquedaInvalida;
      if (error.statusCode == 404) return noDisponible;
      if (error.statusCode >= 500) return errorApi;
    }
    if (error is FormatException) return errorCarga;
    return errorRed;
  }

  static bool puedeReintentar(Object error) =>
      error is! ApiException || error.statusCode != 404;
}
