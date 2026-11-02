import 'package:timezone/data/latest.dart' as zonas;
import 'package:timezone/timezone.dart' as tz;

import 'lectura_json.dart';

// Fechas civiles del contrato: no convertirlas a la zona del teléfono.
class DiaDisponibilidad {
  const DiaDisponibilidad({required this.fecha, required this.disponible});
  final String fecha;
  final bool disponible;

  factory DiaDisponibilidad.fromJson(Map<String, dynamic> json) {
    final fecha = leerTexto(json, 'fecha');
    final valor = DateTime.tryParse(fecha);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fecha) ||
        valor == null ||
        fechaIso(valor) != fecha) {
      throw const FormatException('Fecha de disponibilidad inválida.');
    }
    return DiaDisponibilidad(
      fecha: fecha,
      disponible: leerBooleano(json, 'disponible'),
    );
  }

  DateTime get calendario => DateTime.parse(fecha);
}

class HoraDisponibilidad {
  const HoraDisponibilidad({required this.hora, required this.disponible});
  final String hora;
  final bool disponible;

  factory HoraDisponibilidad.fromJson(Map<String, dynamic> json) {
    final hora = leerTexto(json, 'hora');
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(hora)) {
      throw const FormatException('Hora de disponibilidad inválida.');
    }
    return HoraDisponibilidad(
      hora: hora,
      disponible: leerBooleano(json, 'disponible'),
    );
  }

  DateTime inicio(String fecha) {
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
}

final _zonaMexico = () {
  zonas.initializeTimeZones();
  return tz.getLocation('America/Mexico_City');
}();

String fechaIso(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-'
    '${fecha.month.toString().padLeft(2, '0')}-'
    '${fecha.day.toString().padLeft(2, '0')}';

// MVP-18 / #26: datos civiles del negocio, nunca un DateTime del teléfono.
// Esta selección no registra una reserva; la API deberá revalidarla (RN-39).
class SeleccionDisponibilidad {
  const SeleccionDisponibilidad({
    required this.negocioId,
    required this.servicioId,
    required this.fecha,
    required this.hora,
  });
  final String negocioId;
  final String servicioId;
  final String fecha;
  final String hora;
}
