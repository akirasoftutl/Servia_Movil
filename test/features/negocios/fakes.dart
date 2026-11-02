import 'dart:async';

import 'package:servia/features/negocios/data/categoria.dart';
import 'package:servia/features/negocios/data/negocio.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';

import 'datos_prueba.dart';

class NegociosServiceFalso extends NegociosService {
  Object? error;
  Object? errorCategorias;
  bool aceptaReservas;
  bool catalogoVacio;
  int consultas = 0;
  int consultasCategorias = 0;
  Completer<Negocio>? pendiente;
  NegociosServiceFalso({
    this.error,
    this.errorCategorias,
    this.aceptaReservas = true,
    this.catalogoVacio = false,
  });

  @override
  Future<Negocio> obtenerNegocio(String id) async {
    consultas++;
    if (error != null) throw error!;
    return pendiente?.future ??
        Negocio.fromJson(negocioJson(aceptaReservas: aceptaReservas));
  }

  @override
  Future<List<Categoria>> obtenerCategorias() async {
    consultasCategorias++;
    if (errorCategorias != null) throw errorCategorias!;
    return catalogoVacio
        ? []
        : [
            const Categoria(
              id: 'cabello',
              nombre: 'Cabello y barba',
              orden: 1,
              activo: true,
            ),
          ];
  }
}
