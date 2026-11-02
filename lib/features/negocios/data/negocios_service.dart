import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../mensajes.dart';
import 'categoria.dart';
import 'lectura_json.dart';
import 'negocio.dart';
import 'servicio.dart';

const tiempoLimiteConsulta = Duration(seconds: 10);

bool esIdValido(String id) => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id);

class NegociosService {
  final ApiClient _api;

  NegociosService({ApiClient? api}) : _api = api ?? ApiClient();

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
