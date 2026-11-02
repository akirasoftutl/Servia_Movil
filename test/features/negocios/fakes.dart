import 'dart:async';

import 'package:servia/features/negocios/data/categoria.dart';
import 'package:servia/features/negocios/data/negocio.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
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

class ListaServiceFalso extends NegociosServiceFalso {
  final llamadas = <String?>[];
  final filtros = <({String? q, String? categoriaId})>[];
  List<Categoria>? categorias;

  @override
  Future<List<Categoria>> obtenerCategorias() async =>
      categorias ?? await super.obtenerCategorias();
  late Future<PaginaNegocios> Function(String? cursor) responder;

  ListaServiceFalso() {
    responder = (_) async => const PaginaNegocios(items: [], siguiente: null);
  }

  @override
  Future<PaginaNegocios> listarNegocios({
    String? cursor,
    String? q,
    String? categoriaId,
  }) {
    llamadas.add(cursor);
    filtros.add((q: q, categoriaId: categoriaId));
    return responder(cursor);
  }
}

NegocioResumen resumen(String id, {bool acepta = true}) => NegocioResumen(
  id: id,
  nombre: 'Negocio $id',
  categoriaId: 'cabello',
  aceptaReservas: acepta,
);

PaginaNegocios pagina(List<NegocioResumen> items, [String? siguiente]) =>
    PaginaNegocios(items: items, siguiente: siguiente);
