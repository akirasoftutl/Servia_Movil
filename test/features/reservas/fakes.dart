import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/auth/data/auth_service.dart';
import 'package:servia/features/auth/data/perfil.dart';
import 'package:servia/features/auth/data/perfil_service.dart';
import 'package:servia/features/auth/data/registro_cliente_service.dart';
import 'package:servia/features/negocios/data/disponibilidad.dart';
import 'package:servia/features/negocios/data/disponibilidad_service.dart';
import 'package:servia/features/negocios/data/servicio.dart';
import 'package:servia/features/reservas/data/reserva_creada.dart';
import 'package:servia/features/reservas/data/reserva_resumen.dart';
import 'package:servia/features/reservas/data/reservas_service.dart';
import 'package:servia/features/reservas/resultado_reserva.dart';
import 'package:servia/features/reservas/pages/resumen_reserva_page.dart';

class UsuarioFalso extends Fake implements User {
  @override
  String? get displayName => 'Ana Pérez';

  @override
  String? get email => 'ana@test.com';

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async => 'token';
}

class SesionFalsa extends AuthService {
  SesionFalsa({bool conSesion = true})
    : usuario = conSesion ? UsuarioFalso() : null;
  final eventos = StreamController<User?>.broadcast();
  User? usuario;
  int cierres = 0;
  int inicios = 0;

  @override
  Stream<User?> get cambiosDeSesion async* {
    yield usuario;
    yield* eventos.stream;
  }

  @override
  User? get usuarioActual => usuario;

  @override
  Future<void> iniciarSesion({
    required String correo,
    required String contrasena,
  }) async {
    inicios++;
    usuario = UsuarioFalso();
    eventos.add(usuario);
  }

  @override
  Future<void> cerrarSesion() async {
    cierres++;
    usuario = null;
    eventos.add(null);
  }
}

class PerfilFalso extends PerfilService {
  PerfilFalso({this.tipo = 'cliente', this.error, this.telefono});
  final String tipo;
  final Object? error;
  final String? telefono;
  int consultas = 0;

  @override
  Future<Perfil> obtenerYo(String token) async {
    consultas++;
    if (error != null) throw error!;
    return Perfil(
      uid: 'cliente',
      nombre: 'Ana Pérez',
      correo: 'ana@test.com',
      tipo: tipo,
      telefono: telefono,
    );
  }
}

ReservaCreada reservaCreada({String folio = 'SRV-7KQ2MX'}) => ReservaCreada(
  id: 'r1',
  folio: folio,
  estado: 'pendiente',
  inicio: DateTime.utc(2026, 11, 10, 16),
  fin: DateTime.utc(2026, 11, 10, 17),
  precio: 150,
  duracionMin: 60,
  venceEn: DateTime.utc(2026, 11, 10, 14),
);

class ReservasFalso extends ReservasService {
  ReservasFalso({
    this.error,
    this.espera,
    this.errorListado,
    List<PaginaReservas>? paginas,
  }) : paginas = paginas ?? const [PaginaReservas(items: [], siguiente: null)];

  final Object? error;
  final Completer<void>? espera;

  /// Error devuelto por `listarMias` (distinto del de `crear`).
  final Object? errorListado;

  /// Páginas que se sirven en orden; se repite la última si se pide otra.
  final List<PaginaReservas> paginas;
  final solicitudes = <SolicitudReserva>[];
  final tokens = <String>[];
  final vistas = <String>[];
  final cursores = <String?>[];
  int _pagina = 0;

  @override
  Future<ReservaCreada> crear(String token, SolicitudReserva solicitud) async {
    tokens.add(token);
    solicitudes.add(solicitud);
    if (espera != null) await espera!.future;
    if (error != null) throw error!;
    return reservaCreada();
  }

  @override
  Future<PaginaReservas> listarMias(
    String token, {
    String vista = 'proximas',
    String? cursor,
  }) async {
    tokens.add(token);
    vistas.add(vista);
    cursores.add(cursor);
    if (espera != null) await espera!.future;
    if (errorListado != null) throw errorListado!;
    final indice = _pagina < paginas.length ? _pagina : paginas.length - 1;
    _pagina++;
    return paginas[indice];
  }
}

ReservaResumen reservaResumen({
  String id = 'r1',
  String folio = 'SRV-7KQ2MX',
  String estado = 'pendiente',
  DateTime? inicio,
  DateTime? fin,
  String servicio = 'Corte de cabello',
  String negocio = 'Barbería Central',
}) => ReservaResumen(
  id: id,
  folio: folio,
  estado: estado,
  inicio: inicio ?? DateTime.utc(2026, 11, 10, 16),
  fin: fin ?? DateTime.utc(2026, 11, 10, 17),
  servicio: servicio,
  negocio: negocio,
);

const servicioPrueba = Servicio(
  id: 's1',
  nombre: 'Corte de cabello',
  precio: 150,
  duracionMin: 90,
);

/// Hora de la cita: martes 10 de noviembre de 2026, 10:00 de México (16:00 UTC).
DateTime Function() ahoraEn(DateTime momento) =>
    () => momento;

class ProbadorResumen {
  ResultadoReserva? resultado;
  bool cerrado = false;
}

Future<ProbadorResumen> abrirResumen(
  WidgetTester tester, {
  SesionFalsa? sesion,
  PerfilFalso? perfil,
  ReservasFalso? reservas,
  DateTime? ahora,
  String fecha = '2026-11-10',
  String hora = '10:00',
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final probador = ProbadorResumen();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              probador.resultado = await Navigator.push<ResultadoReserva>(
                context,
                MaterialPageRoute(
                  builder: (_) => ResumenReservaPage(
                    negocioId: 'n1',
                    negocioNombre: 'Barbería Central',
                    servicio: servicioPrueba,
                    fecha: fecha,
                    hora: hora,
                    authService: sesion ?? SesionFalsa(),
                    perfilService: perfil ?? PerfilFalso(),
                    reservasService: reservas ?? ReservasFalso(),
                    ahora: ahoraEn(ahora ?? DateTime.utc(2026, 11, 1, 12)),
                  ),
                ),
              );
              probador.cerrado = true;
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return probador;
}

class DisponibilidadFalsa extends DisponibilidadService {
  int consultasDias = 0;

  @override
  Future<List<DiaDisponibilidad>> obtenerDias(
    String negocioId,
    String servicioId,
  ) async {
    consultasDias++;
    return const [
      DiaDisponibilidad(fecha: '2030-03-04', disponible: true),
      DiaDisponibilidad(fecha: '2030-03-05', disponible: true),
      DiaDisponibilidad(fecha: '2030-03-06', disponible: true),
    ];
  }

  @override
  Future<List<HoraDisponibilidad>> obtenerHoras(
    String negocioId,
    String servicioId,
    String fecha,
  ) async => const [
    HoraDisponibilidad(hora: '11:00', disponible: false),
    HoraDisponibilidad(hora: '11:30', disponible: true),
  ];
}

class RegistroFalso extends RegistroClienteService {
  int registros = 0;

  @override
  Future<RegistroClienteResponse> registrarCliente(
    RegistroClienteRequest request,
  ) async {
    registros++;
    return const RegistroClienteResponse(
      id: 'cliente',
      nombre: 'Ana Pérez',
      correo: 'ana@test.com',
      telefono: '4771234567',
      tipo: 'cliente',
    );
  }
}
