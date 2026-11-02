import 'lectura_json.dart';

const diasSemana = <String, String>{
  'lunes': 'Lunes',
  'martes': 'Martes',
  'miercoles': 'Miércoles',
  'jueves': 'Jueves',
  'viernes': 'Viernes',
  'sabado': 'Sábado',
  'domingo': 'Domingo',
};

class HorarioDia {
  final String abre;
  final String cierra;

  const HorarioDia({required this.abre, required this.cierra});

  factory HorarioDia.fromJson(Map<String, dynamic> json) {
    final abre = leerTexto(json, 'abre');
    final cierra = leerTexto(json, 'cierra');
    final horaValida = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');
    if (!horaValida.hasMatch(abre) || !horaValida.hasMatch(cierra)) {
      throw const FormatException('Horario inválido.');
    }
    return HorarioDia(abre: abre, cierra: cierra);
  }
}

class Negocio {
  final String id;
  final String nombre;
  final String? descripcion;
  final String categoriaId;

  /// Texto armado por la API (`direccionTexto`). El objeto `direccion` no se
  /// lee: la app solo muestra el texto.
  final String? direccionTexto;
  final String? telefono;
  final String? correoContacto;
  final bool aceptaReservas;
  final Map<String, HorarioDia?> horario;

  const Negocio({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.categoriaId,
    this.direccionTexto,
    this.telefono,
    this.correoContacto,
    required this.aceptaReservas,
    required this.horario,
  });

  factory Negocio.fromJson(Map<String, dynamic> json) {
    final horarioJson = leerObjeto(json['horario']);
    final horario = <String, HorarioDia?>{};
    for (final dia in diasSemana.keys) {
      if (!horarioJson.containsKey(dia)) {
        throw const FormatException('Falta un día del horario.');
      }
      final valor = horarioJson[dia];
      horario[dia] = valor == null
          ? null
          : HorarioDia.fromJson(leerObjeto(valor));
    }
    // El teléfono es obligatorio en el contrato, pero puede llegar vacío.
    final telefono = leerTexto(json, 'telefono');
    return Negocio(
      id: leerTexto(json, 'id'),
      nombre: leerTexto(json, 'nombre'),
      descripcion: leerTextoOpcional(json, 'descripcion'),
      categoriaId: leerTexto(json, 'categoriaId'),
      direccionTexto: leerTextoOpcional(json, 'direccionTexto'),
      telefono: telefono.isEmpty ? null : telefono,
      correoContacto: leerTextoOpcional(json, 'correoContacto'),
      aceptaReservas: leerBooleano(json, 'aceptaReservas'),
      horario: Map.unmodifiable(horario),
    );
  }
}
