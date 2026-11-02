import 'package:timezone/data/latest.dart' as zonas;
import 'package:timezone/timezone.dart' as tz;

/// Horas que debe faltar para que el cliente aún pueda cancelar (D4, RN-49).
const horasLimiteCancelacion = 24;

const _meses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const _dias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

final _zonaMexico = () {
  zonas.initializeTimeZones();
  return tz.getLocation('America/Mexico_City');
}();

/// Instante de la cita: fecha `AAAA-MM-DD` y hora `HH:mm` del negocio, leídas
/// en America/Mexico_City y nunca en la zona del teléfono.
DateTime inicioDeCita(String fecha, String hora) {
  final dia = DateTime.parse(fecha);
  final partes = hora.split(':').map(int.parse).toList();
  return tz.TZDateTime(
    _zonaMexico,
    dia.year,
    dia.month,
    dia.day,
    partes[0],
    partes[1],
  );
}

String _dos(int n) => n.toString().padLeft(2, '0');

/// ISO 8601 con la zona de México, por ejemplo `2026-11-10T10:00:00-06:00`.
String inicioIsoConZona(String fecha, String hora) {
  final inicio = inicioDeCita(fecha, hora) as tz.TZDateTime;
  final minutos = inicio.timeZoneOffset.inMinutes;
  final signo = minutos < 0 ? '-' : '+';
  final absolutos = minutos.abs();
  return '${inicio.year.toString().padLeft(4, '0')}-${_dos(inicio.month)}-'
      '${_dos(inicio.day)}T${_dos(inicio.hour)}:${_dos(inicio.minute)}:00'
      '$signo${_dos(absolutos ~/ 60)}:${_dos(absolutos % 60)}';
}

/// La cita es dentro de menos de 24 horas: una vez confirmada ya no se podrá
/// cancelar (D4). Compara instantes, así que no depende de la zona del teléfono.
bool citaEnMenosDe24Horas(DateTime inicio, DateTime ahora) =>
    inicio.difference(ahora) < const Duration(hours: horasLimiteCancelacion);

/// `2026-11-10` -> `martes 10 de noviembre de 2026`.
String formatearFechaLarga(String fecha) {
  final dia = DateTime.parse(fecha);
  return '${_dias[dia.weekday - 1]} ${dia.day} de ${_meses[dia.month - 1]} '
      'de ${dia.year}';
}
