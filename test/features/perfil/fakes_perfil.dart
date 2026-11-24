import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/auth/data/auth_service.dart';
import 'package:servia/features/perfil/data/foto_perfil.dart';
import 'package:servia/features/perfil/data/perfil_cliente.dart';
import 'package:servia/features/perfil/data/perfil_cliente_service.dart';
import 'package:servia/features/perfil/data/selector_foto.dart';

/// Anota en [eventos] cada llamada a la API y a getIdToken, en orden.
class UsuarioPerfilFalso extends Fake implements User {
  UsuarioPerfilFalso(this.eventos);
  final List<String> eventos;
  Object? errorAlRenovar;
  void Function()? alRenovar;

  @override
  String? get displayName => 'Ana Pérez';

  @override
  String? get email => 'ana@test.com';

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

  /// Reautenticación con la contraseña (eliminar la cuenta, HU-C14).
  Object? errorAlReautenticar;
  String? ultimaContrasena;

  @override
  Future<void> reautenticar(String contrasena) async {
    eventos.add('reautenticar');
    ultimaContrasena = contrasena;
    if (errorAlReautenticar != null) throw errorAlReautenticar!;
  }

  @override
  Future<void> cerrarSesionTrasEliminar() async {
    eventos.add('cerrar-sesion');
    usuario = null;
    cambios.add(null);
  }

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
    this.errorAlSubirFoto,
    this.errorAlQuitarFoto,
    this.esperaSubida,
    this.patchSinFoto = false,
  });

  final List<String> eventos;
  final Object? error;
  final Object? errorAlGuardar;
  final Set<String> correosOcupados;
  final Object? errorAlSubirFoto;
  final Object? errorAlQuitarFoto;

  /// Si se da, la subida de la foto espera a que se complete.
  final Completer<void>? esperaSubida;

  /// Simula una API anterior cuyo PATCH no trae `foto`.
  final bool patchSinFoto;
  /// Error de `DELETE /usuarios/yo`; se puede cambiar entre intentos.
  Object? errorAlEliminar;
  int eliminaciones = 0;
  int actualizaciones = 0;
  int subidas = 0;
  int quitadas = 0;
  Uint8List? ultimosBytes;
  String? ultimoNombre;
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
      foto: guardado.foto,
    );
    return patchSinFoto ? guardado.conFoto(null) : guardado;
  }

  @override
  Future<FotoPerfil> subirFoto(
    String token,
    Uint8List bytes,
    String nombre,
  ) async {
    eventos.add('POST-FOTO');
    subidas++;
    ultimosBytes = bytes;
    ultimoNombre = nombre;
    if (esperaSubida != null) await esperaSubida!.future;
    if (errorAlSubirFoto != null) throw errorAlSubirFoto!;
    final foto = FotoPerfil(
      id: 'f$subidas',
      url: 'https://supabase.test/clientes/uid/f$subidas.png',
    );
    guardado = guardado.conFoto(foto);
    return foto;
  }

  @override
  Future<void> eliminarCuenta(String token) async {
    eventos.add('DELETE-CUENTA');
    eliminaciones++;
    if (errorAlEliminar != null) throw errorAlEliminar!;
  }

  @override
  Future<void> quitarFoto(String token) async {
    eventos.add('DELETE-FOTO');
    quitadas++;
    if (errorAlQuitarFoto != null) throw errorAlQuitarFoto!;
    guardado = guardado.conFoto(null);
  }
}

/// PNG de 1x1 válido: se decodifica en las pruebas y trae la firma PNG.
final Uint8List png1x1 = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
);

/// Hace de la galería: devuelve [resultado] y cuenta las veces que se abrió.
class SelectorFotoFalso implements SelectorFoto {
  SelectorFotoFalso(this.resultado, {this.error});
  FotoElegida? resultado;
  final Object? error;
  int aperturas = 0;

  @override
  Future<FotoElegida?> elegir() async {
    aperturas++;
    if (error != null) throw error!;
    return resultado;
  }
}
