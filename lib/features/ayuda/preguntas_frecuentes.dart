/// Preguntas frecuentes del cliente: texto fijo escrito en la app, sin API
/// (HU-C114, HU-C115). Cada respuesta describe algo que la app ya hace y
/// sigue D1 (la reserva nace Pendiente), D2 (una Pendiente ya ocupa el
/// horario), D4 (cancelación) y D5 (vencimiento).
class PreguntaFrecuente {
  const PreguntaFrecuente(
    this.pregunta,
    this.respuesta, {
    this.ofreceReportar = false,
  });

  final String pregunta;
  final String respuesta;

  /// Agrega a la respuesta el botón «Reportar un problema».
  final bool ofreceReportar;
}

class SeccionAyuda {
  const SeccionAyuda(this.titulo, this.preguntas);

  final String titulo;
  final List<PreguntaFrecuente> preguntas;
}

const seccionesAyuda = <SeccionAyuda>[
  SeccionAyuda('Reservar', [
    PreguntaFrecuente(
      '¿Cómo reservo un servicio?',
      'Elige un negocio, un servicio, el día y la hora, y envía la solicitud.',
    ),
    PreguntaFrecuente(
      '¿Mi reserva se confirma sola?',
      'No. Tu solicitud queda Pendiente hasta que el negocio la acepte o la '
          'rechace.',
    ),
  ]),
  SeccionAyuda('Respuesta del negocio', [
    PreguntaFrecuente(
      '¿Cuánto tarda el negocio en responder?',
      'Tiene hasta 2 horas o hasta la hora de la cita, lo que ocurra primero. '
          'Si no responde, la solicitud vence y el horario se libera.',
    ),
    PreguntaFrecuente(
      '¿Mi horario queda apartado mientras espero?',
      'Sí. Una solicitud Pendiente ya ocupa el horario, y se libera si el '
          'negocio la rechaza, si vence o si la cancelas.',
    ),
  ]),
  SeccionAyuda('Cancelar', [
    PreguntaFrecuente(
      '¿Puedo cancelar?',
      'Una reserva Pendiente la puedes retirar en cualquier momento antes de '
          'la cita. Una Confirmada se cancela hasta 24 horas antes de la cita.',
    ),
  ]),
  SeccionAyuda('Cuenta', [
    PreguntaFrecuente(
      '¿Cómo cambio mis datos o mi contraseña?',
      'En Mi perfil puedes editar tus datos y cambiar tu contraseña. Si la '
          'olvidaste, en el inicio de sesión toca «¿Olvidaste tu contraseña?».',
    ),
  ]),
  SeccionAyuda('Problemas', [
    PreguntaFrecuente(
      'Algo no funciona',
      'Cuéntanos qué pasó con el formulario de reporte y lo revisamos.',
      ofreceReportar: true,
    ),
  ]),
];
