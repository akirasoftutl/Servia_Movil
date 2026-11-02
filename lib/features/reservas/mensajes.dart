import 'dart:async';

import '../../core/network/api_exception.dart';

class MensajesReservas {
  MensajesReservas._();

  static const titulo = 'Resumen de tu reserva';
  static const negocio = 'Negocio';
  static const servicio = 'Servicio';
  static const fecha = 'Fecha';
  static const hora = 'Hora';
  static const duracion = 'Duración';
  static const precioTotal = 'Precio total';
  static const contacto = 'Tus datos de contacto';
  static const observaciones = 'Observaciones (opcional)';
  static const observacionesAyuda = 'Por ejemplo: llego 5 minutos antes.';
  static const maxObservaciones = 500;
  static const enviar = 'Enviar solicitud';
  static const enviando = 'Enviando...';
  static const sinCancelacion =
      'Tu cita es en menos de 24 horas. Una vez confirmada por el negocio, '
      'ya no podrás cancelarla.';
  static const avisoDosHoras =
      'El negocio tiene hasta 2 horas para aceptar tu solicitud.';
  static const horarioOcupado =
      'Ese horario ya no está libre. Elige otro horario.';
  static const cargandoContacto = 'Cargando tus datos...';
  static const soloClientes = 'Solo las cuentas de cliente pueden reservar.';
  static const sesionVencida =
      'Tu sesión ya no es válida. Inicia sesión de nuevo para reservar.';
  static const datosInvalidos =
      'No se pudo enviar la solicitud. Revisa la fecha y la hora: no puede '
      'ser pasada ni estar a más de 30 días.';
  static const noDisponible =
      'Este servicio o negocio ya no está disponible para reservar.';
  static const errorApi = 'La API no está disponible. Intenta más tarde.';
  static const errorRed =
      'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.';
  static const errorGeneral =
      'No se pudo enviar la solicitud. Inténtalo de nuevo.';
  static const iniciarSesionParaReservar =
      'Inicia sesión con tu cuenta de cliente para reservar.';
  static const confirmacionTitulo = 'Solicitud enviada';
  static const folio = 'Folio';
  static const estado = 'Estado';
  static const estadoPendiente = 'Pendiente';
  static const volverAlInicio = 'Volver al inicio';

  /// Mensaje de [error] al enviar la solicitud. El 409 lo atiende el flujo.
  static String mensajeDeEnvio(Object error) {
    if (error is TimeoutException) return errorRed;
    if (error is ApiException) {
      switch (error.statusCode) {
        case 400:
          return datosInvalidos;
        case 401:
          return sesionVencida;
        case 403:
          return soloClientes;
        case 404:
          return noDisponible;
        case 409:
          return horarioOcupado;
      }
      if (error.statusCode >= 500) return errorApi;
      return errorGeneral;
    }
    if (error is FormatException) return errorGeneral;
    return errorRed;
  }
}
