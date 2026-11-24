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

  // Cancelación del cliente (MVP-21, D4).
  static const retirarSolicitud = 'Retirar solicitud';
  static const cancelarReserva = 'Cancelar reserva';
  static const cancelando = 'Cancelando...';
  static const limiteCancelacion =
      'Ya no puedes cancelar esta reserva: las reservas confirmadas solo se cancelan hasta 24 horas antes de la cita.';
  static const condicionesCancelacion = 'Condiciones de cancelación';
  static const condicionesPendiente =
      'Puedes retirar una solicitud pendiente en cualquier momento antes de la cita.';
  static const condicionesConfirmada =
      'Una reserva confirmada solo se puede cancelar hasta 24 horas antes de la cita.';
  static const condicionesIrreversible =
      'Una vez cancelada, la reserva no se puede reactivar. Si después quieres el servicio, haz una nueva reserva.';
  static const siCancelar = 'Sí, cancelar';
  static const noVolver = 'No, volver';
  static const cancelacionExitosa =
      'Tu reserva fue cancelada. El horario quedó libre.';
  static const reservaYaNoDisponible = 'Esta reserva ya no está disponible.';
  static const errorCancelacion =
      'No se pudo cancelar tu reserva. Inténtalo de nuevo.';

  static String mensajeDeCancelacion(Object error) {
    if (sesionInvalidaDetalle(error)) return sesionVencidaConsulta;
    if (error is ApiException) {
      if (error.statusCode == 409) return error.mensaje;
      if (error.statusCode == 404) return reservaYaNoDisponible;
      return error.statusCode >= 500 ? errorApi : errorCancelacion;
    }
    if (error is FormatException) return errorCancelacion;
    return errorRed;
  }

  // Cambiar fecha, hora o servicio (T18, T19; HU-C71 a HU-C74).
  static const cambiarFechaHora = 'Cambiar fecha u hora';
  static const tituloReprogramar = 'Cambiar tu reserva';
  static const citaActual = 'Tu cita actual';
  static const servicioDeLaCita = 'Servicio';
  static const cambiarDeServicio = 'Cambiar de servicio';
  static const ocultarServicios = 'Dejar el servicio actual';
  static const cargandoServicios = 'Cargando los servicios...';
  static const sinOtrosServicios =
      'Este negocio no tiene otros servicios activos.';
  static const errorServicios =
      'No se pudieron cargar los servicios. Inténtalo de nuevo.';
  static const servicioElegido = 'Servicio elegido';
  static const elegirFechaHora = 'Elegir nueva fecha y hora';
  static const puedesCambiarHasta = 'Puedes cambiar esta reserva hasta el';
  static const confirmarCambio = 'Confirmar cambio';
  static const ahoraEs = 'Ahora';
  static const nuevaCita = 'Nueva cita';
  static const servicioAntes = 'Antes';
  static const avisoVuelvePendiente =
      'Tu reserva volverá a quedar Pendiente y el negocio tendrá que aceptarla de nuevo.';
  static const siCambiar = 'Sí, cambiar';
  static const reprogramando = 'Cambiando...';
  static const reprogramacionExitosa =
      'Tu reserva se cambió. El negocio debe aceptarla de nuevo.';
  static const errorReprogramacion =
      'No se pudo cambiar tu reserva. Inténtalo de nuevo.';

  /// «Tu reserva quedó Pendiente para el … a las …. El negocio debe confirmarla.»
  static String reprogramada(String fecha, String hora) =>
      'Tu reserva quedó Pendiente para el $fecha a las $hora. '
      'El negocio debe confirmarla.';

  /// Mensaje de [error] al enviar el cambio. El 409 trae el texto de la API.
  static String mensajeDeReprogramacion(Object error) {
    if (sesionInvalidaDetalle(error)) return sesionVencidaConsulta;
    if (error is ApiException) {
      if (error.statusCode == 400 || error.statusCode == 409) {
        return error.mensaje;
      }
      if (error.statusCode == 404) return reservaYaNoDisponible;
      return error.statusCode >= 500 ? errorApi : errorReprogramacion;
    }
    if (error is FormatException) return errorReprogramacion;
    return errorRed;
  }

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

  static bool sesionInvalidaDetalle(Object error) =>
      error is ApiException &&
      (error.statusCode == 401 || error.statusCode == 403);

  static String mensajeDeDetalle(Object error) {
    if (sesionInvalidaDetalle(error)) return sesionVencidaConsulta;
    if (error is ApiException) {
      return error.statusCode >= 500 ? errorApi : errorDetalle;
    }
    if (error is FormatException) return errorDetalle;
    return errorRed;
  }

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
