import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/auth/data/auth_service.dart';
import 'package:servia/features/perfil/data/perfil_cliente.dart';
import 'package:servia/features/perfil/data/perfil_cliente_service.dart';

/// Anota en [eventos] cada llamada a la API y a getIdToken, en orden.
class UsuarioPerfilFalso extends Fake implements User {
  UsuarioPerfilFalso(this.eventos);
  final List<String> eventos;
  Object? errorAlRenovar;
  void Function()? alRenovar;

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    eventos.add(forceRefresh ? 'token-nuevo' : 'token');
    if (forceRefresh) {
      alRenovar?.call();
      if (errorAlRenovar != null) throw errorAlRenovar!;
    }
    return 'tok';
  }
}

class SesionPerfilFalsa extends AuthService {
  SesionPerfilFalsa(this.eventos) {
    usuario = UsuarioPerfilFalso(eventos);
  }
  final List<String> eventos;
  User? usuario;
  UsuarioPerfilFalso get usuarioFalso => usuario! as UsuarioPerfilFalso;

  final cambios = StreamController<User?>.broadcast();

  @override
  User? get usuarioActual => usuario;

  @override
  Stream<User?> get cambiosDeSesion async* {
    yield usuario;
    yield* cambios.stream;
  }

  @override
  Future<void> cerrarSesion() async {
    usuario = null;
    cambios.add(null);
  }
}

/// Hace de API: guarda el perfil en memoria y responde como el contrato de Servia_BE#64.
class PerfilClienteFalso extends PerfilClienteService {
  PerfilClienteFalso(
    this.eventos, {
    this.error,
    this.errorAlGuardar,
    this.correosOcupados = const {},
  });

  final List<String> eventos;
  final Object? error;
  final Object? errorAlGuardar;
  final Set<String> correosOcupados;
  int actualizaciones = 0;
  Map<String, String?> ultimoPatch = {};
  PerfilCliente guardado = const PerfilCliente(
    nombre: 'Ana Pérez',
    correo: 'ana@test.com',
    telefono: '4771234567',
  );

  @override
  Future<PerfilCliente> obtener(String token) async {
    eventos.add('GET');
    if (error != null) throw error!;
    return guardado;
  }

  @override
  Future<PerfilCliente> actualizar(
    String token, {
    String? nombre,
    String? telefono,
    String? correo,
  }) async {
    eventos.add('PATCH');
    actualizaciones++;
    ultimoPatch = {'nombre': nombre, 'telefono': telefono, 'correo': correo};
    if (errorAlGuardar != null) throw errorAlGuardar!;
    if (correo != null && correosOcupados.contains(correo)) {
      throw ApiException(409, 'Ese correo ya está en uso.');
    }
    guardado = PerfilCliente(
      nombre: nombre ?? guardado.nombre,
      correo: correo ?? guardado.correo,
      telefono: telefono ?? guardado.telefono,
    );
    return guardado;
  }
}
