import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../mensajes.dart';
import 'categoria.dart';
import 'lectura_json.dart';
import 'negocio.dart';
import 'negocio_resumen.dart';

const tiempoLimiteConsulta = Duration(seconds: 10);

bool esIdValido(String id) => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id);

class NegociosService {
  final ApiClient _api;

  NegociosService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<PaginaNegocios> listarNegocios({
    String? cursor,
    String? q,
    String? categoriaId,
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
