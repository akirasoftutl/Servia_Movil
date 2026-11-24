import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/features/auth/data/auth_service.dart';
import 'package:servia/features/favoritos/data/favoritos_controlador.dart';
import 'package:servia/features/favoritos/data/favoritos_service.dart';
import 'package:servia/features/favoritos/data/favoritos_servicios_controlador.dart';

class UsuarioFavoritos extends Fake implements User {
  UsuarioFavoritos(this.uid);

  @override
  final String uid;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token-$uid';
}

/// Sesión de la app: [usuario] null = sin sesión; se cambia para simular
/// cerrar sesión y entrar con otra cuenta.
class SesionFavoritos extends AuthService {
  SesionFavoritos([String? uid])
    : usuario = uid == null ? null : UsuarioFavoritos(uid);

  User? usuario;

  @override
  User? get usuarioActual => usuario;
}

/// Negocio tal como lo devuelve `GET /favoritos/negocios` (BE#111).
Map<String, dynamic> negocioFavorito(
  String id, {
  String? nombre,
  String? categoriaId = 'cabello',
  bool aceptaReservas = true,
  String? portadaUrl,
}) => {
  'id': id,
  'nombre': nombre ?? 'Negocio $id',
  'categoriaId': categoriaId,
  'fotos': {
    'portada': portadaUrl == null ? null : {'id': 'f-$id', 'url': portadaUrl},
    'galeria': <Map<String, dynamic>>[],
  },
  'aceptaReservas': aceptaReservas,
};

/// Servicio tal como lo devuelve `GET /favoritos/servicios` (BE#122): sin
/// descripción y con el nombre del negocio; `precio` es un número.
Map<String, dynamic> servicioFavorito(
  String negocioId,
  String servicioId, {
  String? nombre,
  num precio = 150.5,
  int duracionMin = 45,
  String? negocioNombre,
  bool aceptaReservas = true,
}) => {
  'servicioId': servicioId,
  'nombre': nombre ?? 'Servicio $servicioId',
  'precio': precio,
  'duracionMin': duracionMin,
  'negocioId': negocioId,
  'negocioNombre': negocioNombre ?? 'Negocio $negocioId',
  'aceptaReservas': aceptaReservas,
};

/// Hace de la API de favoritos (contrato de Servia_BE#111 y #122): `GET`, `PUT` y
/// `DELETE` de `/favoritos/negocios`, con los favoritos de cada cuenta por
/// separado, del más reciente al más antiguo.
class ApiFavoritosFalsa {
  ApiFavoritosFalsa({Map<String, List<Map<String, dynamic>>>? porCuenta})
    : porCuenta = porCuenta ?? {};

  /// Clave: uid de la cuenta (el token de las pruebas es `token-<uid>`).
  final Map<String, List<Map<String, dynamic>>> porCuenta;

  /// Negocios que la API ya no considera visibles (PUT responde 404).
  final noDisponibles = <String>{};

  int tope = 100;

  /// Favoritos de servicios por cuenta, del más reciente al más antiguo.
  final serviciosPorCuenta = <String, List<Map<String, dynamic>>>{};

  /// Servicios que la API ya no considera disponibles (PUT responde 404),
  /// como `negocioId/servicioId`.
  final serviciosNoDisponibles = <String>{};

  int topeServicios = 100;

  /// Como [errores], pero para `/favoritos/servicios`.
  final erroresServicios = <String, ({int codigo, String? mensaje})>{};

  /// Si no es null, la siguiente petición de ese método responde con él.
  final errores = <String, ({int codigo, String? mensaje})>{};

  /// Mientras exista, las respuestas esperan a que se complete.
  Completer<void>? retener;

  final peticiones = <http.Request>[];

  List<Map<String, dynamic>> de(String uid) =>
      porCuenta.putIfAbsent(uid, () => []);

  List<Map<String, dynamic>> serviciosDe(String uid) =>
      serviciosPorCuenta.putIfAbsent(uid, () => []);

  List<String> metodos() => [
    for (final p in peticiones) '${p.method} ${p.url.path}',
  ];

  http.Response _json(int codigo, Object? cuerpo) => http.Response(
    jsonEncode(cuerpo),
    codigo,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  http.Response _error(int codigo, String mensaje) => _json(codigo, {
    'statusCode': codigo,
    'message': mensaje,
    'error': switch (codigo) {
      401 => 'Unauthorized',
      403 => 'Forbidden',
      404 => 'Not Found',
      409 => 'Conflict',
      _ => 'Internal Server Error',
    },
  });

  Future<http.Response> _atender(http.Request peticion) async {
    peticiones.add(peticion);
    if (retener != null) await retener!.future;
    final autorizacion = peticion.headers['Authorization'] ?? '';
    if (!autorizacion.startsWith('Bearer token-')) {
      return _error(401, 'Unauthorized');
    }
    final uid = autorizacion.substring('Bearer token-'.length);
    final ruta = peticion.url.path;
    final deServicios = ruta.startsWith('/favoritos/servicios');
    final forzado = (deServicios ? erroresServicios : errores)[peticion.method];
    if (forzado != null) {
      return _error(forzado.codigo, forzado.mensaje ?? 'Error');
    }
    if (deServicios) return _atenderServicios(peticion, uid);
    final lista = de(uid);
    if (peticion.method == 'GET' && ruta == '/favoritos/negocios') {
      return _json(200, {'items': lista});
    }
    final id = ruta.startsWith('/favoritos/negocios/')
        ? Uri.decodeComponent(ruta.substring('/favoritos/negocios/'.length))
        : null;
    if (id == null) return _error(404, 'Cannot ${peticion.method} $ruta');
    if (peticion.method == 'PUT') {
      if (noDisponibles.contains(id)) {
        return _error(404, 'Negocio no encontrado o no está disponible.');
      }
      if (lista.any((n) => n['id'] == id)) return http.Response('', 204);
      if (lista.length >= tope) {
        return _error(
          409,
          'Llegaste al máximo de $tope favoritos. Quita alguno para agregar otro.',
        );
      }
      lista.insert(0, negocioFavorito(id));
      return http.Response('', 204);
    }
    if (peticion.method == 'DELETE') {
      lista.removeWhere((n) => n['id'] == id);
      return http.Response('', 204);
    }
    return _error(404, 'Cannot ${peticion.method} $ruta');
  }

  /// `GET /favoritos/servicios` → 200 `{ items }`;
  /// `PUT` y `DELETE /favoritos/servicios/{negocioId}/{servicioId}` → 204.
  http.Response _atenderServicios(http.Request peticion, String uid) {
    final lista = serviciosDe(uid);
    final ruta = peticion.url.path;
    if (peticion.method == 'GET' && ruta == '/favoritos/servicios') {
      return _json(200, {'items': lista});
    }
    final partes = ruta.startsWith('/favoritos/servicios/')
        ? ruta.substring('/favoritos/servicios/'.length).split('/')
        : <String>[];
    if (partes.length != 2) {
      return _error(404, 'Cannot ${peticion.method} $ruta');
    }
    final negocioId = Uri.decodeComponent(partes[0]);
    final servicioId = Uri.decodeComponent(partes[1]);
    bool esEse(Map<String, dynamic> s) =>
        s['negocioId'] == negocioId && s['servicioId'] == servicioId;
    if (peticion.method == 'PUT') {
      if (serviciosNoDisponibles.contains('$negocioId/$servicioId')) {
        return _error(404, 'Servicio no encontrado o no está disponible.');
      }
      if (lista.any(esEse)) return http.Response('', 204);
      if (lista.length >= topeServicios) {
        return _error(
          409,
          'Llegaste al máximo de $topeServicios servicios favoritos. '
          'Quita alguno para agregar otro.',
        );
      }
      lista.insert(0, servicioFavorito(negocioId, servicioId));
      return http.Response('', 204);
    }
    if (peticion.method == 'DELETE') {
      lista.removeWhere(esEse);
      return http.Response('', 204);
    }
    return _error(404, 'Cannot ${peticion.method} $ruta');
  }

  ApiClient get cliente => ApiClient(client: MockClient(_atender));

  FavoritosService get servicio => FavoritosService(api: cliente);

  FavoritosControlador controlador(AuthService auth) =>
      FavoritosControlador(service: servicio, auth: auth);

  FavoritosServiciosControlador controladorServicios(AuthService auth) =>
      FavoritosServiciosControlador(service: servicio, auth: auth);
}
