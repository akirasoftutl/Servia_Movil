import 'package:servia/features/negocios/data/negocio.dart';
import 'package:servia/features/negocios/data/servicio.dart';

Map<String, dynamic> negocioJson({bool aceptaReservas = true}) => {
  'id': 'abc123',
  'nombre': 'Salón Aurora',
  'descripcion': 'Cuidado personal',
  'categoriaId': 'cabello',
  'direccion': 'Calle Luna 12',
  'telefono': '4771234567',
  'correoContacto': 'aurora@example.test',
  'aceptaReservas': aceptaReservas,
  'horario': {
    for (final dia in diasSemana.keys)
      dia: dia == 'domingo' ? null : {'abre': '09:00', 'cierra': '18:00'},
  },
};

const serviciosPrueba = [
  Servicio(id: 's2', nombre: 'Z Corte', precio: 150, duracionMin: 90),
  Servicio(id: 's1', nombre: 'A Masaje', precio: 150.5, duracionMin: 30),
];

const detallePrueba = Servicio(
  id: 's2',
  nombre: 'Z Corte',
  descripcion: 'Lavado y corte de cabello',
  precio: 150.5,
  duracionMin: 90,
);
