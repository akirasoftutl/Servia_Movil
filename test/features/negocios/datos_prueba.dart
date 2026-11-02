import 'package:servia/features/negocios/data/negocio.dart';

Map<String, dynamic> negocioJson({bool aceptaReservas = true}) => {
  'id': 'abc123',
  'nombre': 'Salón Aurora',
  'descripcion': 'Cuidado personal',
  'categoriaId': 'cabello',
  'categoria': 'Categoría de API',
  'direccion': 'Calle Luna 12',
  'telefono': '4771234567',
  'correoContacto': 'aurora@example.test',
  'aceptaReservas': aceptaReservas,
  'horario': {
    for (final dia in diasSemana.keys)
      dia: dia == 'domingo' ? null : {'abre': '09:00', 'cierra': '18:00'},
  },
};
