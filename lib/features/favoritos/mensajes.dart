import 'dart:async';

import '../../core/network/api_exception.dart';
import '../negocios/mensajes.dart';

/// Textos visibles de los favoritos del cliente (HU-C81 a HU-C83, T17).
class MensajesFavoritos {
  MensajesFavoritos._();

  static const titulo = 'Mis favoritos';
  static const agregar = 'Agregar a favoritos';
  static const quitar = 'Quitar de favoritos';
  static const reintentarEstado =
      'No se pudo comprobar tus favoritos. Toca para reintentar.';
  static const sinFavoritos = 'Todavía no tienes negocios favoritos.';
  static const errorCarga = 'No se pudieron cargar tus favoritos.';
  static const cargando = 'Cargando tus favoritos...';
  static const errorGuardar =
      'No se pudo actualizar tus favoritos. Inténtalo de nuevo.';
  static const sesionVencida =
      'Tu sesión ya no es válida. Inicia sesión de nuevo.';
  static const soloClientes =
      'Solo las cuentas de cliente tienen negocios favoritos.';

  static const tabNegocios = 'Negocios';
  static const tabServicios = 'Servicios';
  static const sinServicios = 'Todavía no tienes servicios favoritos.';
  static const servicioNoDisponible = 'Este servicio no está disponible.';

  /// Tope de servicios de la API (T19); solo si el 409 no trae mensaje.
  static const limiteServicios =
      'Llegaste al máximo de 100 servicios favoritos. Quita alguno para agregar otro.';

  /// Tope de la API (T19); se usa solo si la respuesta 409 no trae mensaje.
  static const limite =
      'Llegaste al máximo de 100 favoritos. Quita alguno para agregar otro.';

  static bool _sesion(Object error) =>
      error is ApiException &&
      (error.statusCode == 401 || error.statusCode == 403);

  /// Con la sesión vencida no se ofrece reintentar: hay que iniciar sesión.
  static bool puedeReintentarCarga(Object error) =>
      error is! ApiException || error.statusCode != 401;

  /// Mensaje al consultar `GET /favoritos/negocios`.
  static String mensajeDeCarga(Object error) =>
      _sesion(error) ? _deSesion(error as ApiException) : errorCarga;

  /// Mensaje al agregar o quitar un favorito (404 y 409 como en la API).
  /// Con [servicio] los textos son los de un servicio favorito (HU-C84).
  static String mensajeDeCambio(Object error, {bool servicio = false}) {
    if (error is ApiException) {
      switch (error.statusCode) {
        case 401:
        case 403:
          return _deSesion(error);
        case 404:
          return servicio
              ? servicioNoDisponible
              : MensajesNegocios.noDisponible;
        case 409:
          return error.mensaje.trim().isEmpty
              ? (servicio ? limiteServicios : limite)
              : error.mensaje;
      }
      if (error.statusCode >= 500) return MensajesNegocios.errorApi;
      return errorGuardar;
    }
    if (error is FormatException) return errorGuardar;
    if (error is TimeoutException) return MensajesNegocios.errorRed;
    return MensajesNegocios.errorRed;
  }

  static String _deSesion(ApiException error) =>
      error.statusCode == 403 ? soloClientes : sesionVencida;
}
