import 'data/negocio.dart';
import 'mensajes.dart';

String formatearHorario(HorarioDia? horario) => horario == null
    ? MensajesNegocios.descanso
    : '${horario.abre} – ${horario.cierra}';
