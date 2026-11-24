import 'dart:async';

import 'package:servia/features/negocios/data/negocio_resumen.dart';

import 'fakes.dart';

/// Forma exacta de `GET /negocios/destacados` (Servia_BE#118): cada item es un
/// `NegocioPublicoDto` como el de `GET /negocios`.
Map<String, dynamic> destacadoJson(
  String id, {
  String? categoriaId = 'cabello',
  String? portada,
  bool aceptaReservas = true,
}) => {
  'id': id,
  'nombre': 'Destacado $id',
  'categoriaId': categoriaId,
  'fotos': {
    'portada': portada == null ? null : {'id': 'f-$id', 'url': portada},
    'galeria': <Map<String, dynamic>>[],
  },
  'aceptaReservas': aceptaReservas,
};

NegocioResumen destacado(String id, {String? categoriaId = 'cabello'}) =>
    NegocioResumen.fromJson(destacadoJson(id, categoriaId: categoriaId));

/// Lista de negocios con destacados simulados.
class ListaConDestacados extends ListaServiceFalso {
  List<NegocioResumen> destacados = [];
  Object? errorDestacados;
  Completer<List<NegocioResumen>>? destacadosPendientes;
  int consultasDestacados = 0;

  @override
  Future<List<NegocioResumen>> obtenerDestacados() async {
    consultasDestacados++;
    if (errorDestacados != null) throw errorDestacados!;
    return destacadosPendientes?.future ?? destacados;
  }
}
