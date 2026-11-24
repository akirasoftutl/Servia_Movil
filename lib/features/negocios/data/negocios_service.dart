import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../mensajes.dart';
import 'categoria.dart';
import 'lectura_json.dart';
import 'negocio.dart';
import 'negocio_cercano.dart';
import 'negocio_resumen.dart';
import 'orden_negocios.dart';
import 'servicio.dart';

const tiempoLimiteConsulta = Duration(seconds: 10);

bool esIdValido(String id) => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id);

class NegociosService {
  final ApiClient _api;

  NegociosService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<NegocioCercano>> obtenerCercanos({
    required double lat,
    required double lng,
  }) async {
    final ruta = Uri(
      path: '/negocios/cercanos',
      queryParameters: {'lat': '$lat', 'lng': '$lng', 'radioKm': '20'},
    );
    final datos = await _consultar(ruta.toString());
    if (datos is! List) {
      throw const FormatException('Lista de cercanos inválida.');
    }
    // RN-08, RN-10 y RN-11: la API entrega solo negocios visibles.
    final negocios =
        datos
            .map((dato) => NegocioCercano.fromJson(leerObjeto(dato)))
            .where((negocio) => negocio.distanciaKm <= 20)
            .toList()
          ..sort((a, b) => a.distanciaKm.compareTo(b.distanciaKm));
    return List.unmodifiable(negocios.take(5));
  }

  Future<PaginaNegocios> listarNegocios({
    String? cursor,
    String? q,
    String? categoriaId,
    OrdenNegocios orden = OrdenNegocios.nombre,
  }) async {
    final texto = q?.trim();
    final categoria = categoriaId?.trim();
    final ruta = Uri(
      path: '/negocios',
      queryParameters: {
        'limite': '20',
        'cursor': ?cursor,
        if (texto != null && texto.length >= 2)
          'q': texto.length > 50 ? texto.substring(0, 50) : texto,
        if (categoria != null && categoria.isNotEmpty) 'categoriaId': categoria,
        // A-Z es el orden por omisión de la API: no se manda.
        'orden': ?orden.valorApi,
      },
    );
    final datos = await _consultar(ruta.toString());
    return PaginaNegocios.fromJson(leerObjeto(datos));
  }

  Future<Negocio> obtenerNegocio(String id) async {
    if (!esIdValido(id)) {
      throw const ApiException(404, MensajesNegocios.noDisponible);
    }
    final datos = await _consultar('/negocios/${Uri.encodeComponent(id)}');
    return Negocio.fromJson(leerObjeto(datos));
  }

  Future<List<Categoria>> obtenerCategorias() async {
    final datos = await _consultar('/categorias');
    if (datos is! List) throw const FormatException('Catálogo inválido.');
    return datos.map((dato) => Categoria.fromJson(leerObjeto(dato))).toList();
  }

  Future<List<Servicio>> obtenerServicios(String negocioId) async {
    if (!esIdValido(negocioId)) {
      throw const ApiException(404, MensajesNegocios.noDisponible);
    }
    final datos = await _consultar(
      '/negocios/${Uri.encodeComponent(negocioId)}/servicios',
    );
    if (datos is! List) {
      throw const FormatException('Lista de servicios inválida.');
    }
    return datos.map((dato) => Servicio.fromJson(leerObjeto(dato))).toList();
  }

  Future<Servicio> obtenerServicio(String negocioId, String servicioId) async {
    if (!esIdValido(negocioId) || !esIdValido(servicioId)) {
      throw const ApiException(404, MensajesNegocios.servicioNoDisponible);
    }
    final datos = await _consultar(
      '/negocios/${Uri.encodeComponent(negocioId)}/servicios/${Uri.encodeComponent(servicioId)}',
    );
    final servicio = Servicio.fromJson(leerObjeto(datos));
    if (servicio.descripcion == null) {
      throw const FormatException('Falta la descripción del servicio.');
    }
    return servicio;
  }

  Future<Object?> _consultar(String ruta) async {
    final respuesta = await _api.get(ruta).timeout(tiempoLimiteConsulta);
    if (respuesta.statusCode == 200) return jsonDecode(respuesta.body);
    final mensaje = respuesta.statusCode == 404
        ? MensajesNegocios.noDisponible
        : respuesta.statusCode >= 500
        ? MensajesNegocios.errorApi
        : MensajesNegocios.errorCarga;
    throw ApiException(respuesta.statusCode, mensaje);
  }
}
