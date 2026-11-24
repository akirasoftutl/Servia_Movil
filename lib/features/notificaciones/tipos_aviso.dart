import 'package:flutter/material.dart';

/// Tipo de aviso que manda la API cuando se acerca la cita (HU-C79, Servia_BE#112).
const tipoRecordatorioCita = 'RECORDATORIO_CITA';

/// Ícono de un aviso según su `tipo`. Un tipo que la app no conoce (la API
/// puede agregar otros) usa el ícono genérico y se muestra igual.
IconData iconoDeAviso(String tipo) => switch (tipo) {
  tipoRecordatorioCita => Icons.alarm,
  _ => Icons.notifications_none,
};
