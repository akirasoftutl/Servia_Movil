import 'data/negocio.dart';
import 'mensajes.dart';

String formatearHorario(HorarioDia? horario) => horario == null
    ? MensajesNegocios.descanso
    : '${horario.abre} – ${horario.cierra}';

const minutosPorHora = 60;
const decimalesPrecio = 2;

String formatearPrecio(num precio) =>
    '\$${precio == precio.truncateToDouble() ? precio.toStringAsFixed(0) : precio.toStringAsFixed(decimalesPrecio)}';

String formatearDuracion(int minutos) {
  final horas = minutos ~/ minutosPorHora;
  final resto = minutos % minutosPorHora;
  if (horas == 0) return '$minutos min';
  return resto == 0 ? '$horas h' : '$horas h $resto min';
}
