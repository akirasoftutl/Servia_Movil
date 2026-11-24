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
  SesionFavoritos([String? uid]) : usuario = uid == null ? null : UsuarioFavoritos(uid);

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

/// Hace de la API de favoritos (contrato de Servia_BE#111): `GET`, `PUT` y
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

  /// Si no es null, la siguiente petición de ese método responde con él.
  final errores = <String, ({int codigo, String? mensaje})>{};

  /// Mientras exista, las respuestas esperan a que se complete.
  Completer<void>? retener;

  final peticiones = <http.Request>[];

  List<Map<String, dynamic>> de(String uid) => porCuenta.putIfAbsent(uid, () => []);

  List<String> metodos() => [for (final p in peticiones) '${p.method} ${p.url.path}'];

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
    final forzado = errores[peticion.method];
    if (forzado != null) {
      return _error(forzado.codigo, forzado.mensaje ?? 'Error');
    }
    final lista = de(uid);
    final ruta = peticion.url.path;
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

  ApiClient get cliente => ApiClient(client: MockClient(_atender));

  FavoritosService get servicio => FavoritosService(api: cliente);

  FavoritosControlador controlador(AuthService auth) =>
      FavoritosControlador(service: servicio, auth: auth);
}
