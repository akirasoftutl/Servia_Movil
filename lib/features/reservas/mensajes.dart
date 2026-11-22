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

  // «Mis reservas» (MVP-19).
  static const tituloMisReservas = 'Mis reservas';
  static const tabProximas = 'Próximas';
  static const tabHistorial = 'Historial';
  static const sinReservasProximas = 'No tienes reservas próximas.';
  static const sinReservasHistorial =
      'Todavía no tienes reservas en tu historial.';
  static const cargandoReservas = 'Cargando tus reservas...';
  static const cargando = 'Cargando...';
  static const cargarMas = 'Cargar más';
  static const sesionVencidaConsulta =
      'Tu sesión ya no es válida. Inicia sesión de nuevo.';
  static const errorConsulta =
      'No se pudieron cargar tus reservas. Inténtalo de nuevo.';
  static const estadoConfirmada = 'Confirmada';
  static const estadoRechazada = 'Rechazada';
  static const estadoRechazadaVencimiento = 'Rechazada por vencimiento';
  static const estadoCancelada = 'Cancelada';
  static const estadoCompletada = 'Completada';

  // Detalle de reserva (MVP-20).
  static const tituloDetalle = 'Detalle de la reserva';
  static const cargandoDetalle = 'Cargando tu reserva...';
  static const fechaYHora = 'Fecha y hora';
  static const observacionesDetalle = 'Observaciones';
  static const sinObservaciones = 'Sin observaciones.';
  static const datoNoDisponible = 'No disponible';
  static const reservaNoEncontrada = 'No encontramos esta reserva.';
  static const volverAMisReservas = 'Volver a mis reservas';
  static bool detalleNoEncontrado(Object error) =>
      error is ApiException &&
      (error.statusCode == 400 || error.statusCode == 404);

  static const motivoRechazo = 'Motivo del rechazo';
  static const motivoCancelacion = 'Motivo de la cancelación';
  static const errorDetalle =
      'No se pudo cargar tu reserva. Inténtalo de nuevo.';

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

  /// Mensaje de [error] al consultar `GET /reservas/mias`.
  static String mensajeDeListado(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) return sesionVencidaConsulta;
      if (error.statusCode >= 500) return errorApi;
      return errorConsulta;
    }
    if (error is TimeoutException) return errorRed;
    if (error is FormatException) return errorConsulta;
    return errorRed;
  }

  /// Con la sesión vencida no se ofrece reintentar: hay que iniciar sesión.
  static bool puedeReintentarListado(Object error) =>
      error is! ApiException || error.statusCode != 401;
}
