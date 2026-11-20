import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/auth/mensajes.dart';
import 'package:servia/features/auth/pages/auth_gate.dart';
import 'package:servia/features/auth/pages/login_page.dart';
import 'package:servia/features/auth/pages/register_page.dart';
import 'package:servia/features/negocios/pages/detalle_servicio_page.dart';
import 'package:servia/features/negocios/pages/disponibilidad_page.dart';
import 'package:servia/features/reservas/flujo_reserva.dart';
import 'package:servia/features/reservas/mensajes.dart';
import 'package:servia/features/reservas/pages/confirmacion_reserva_page.dart';
import 'package:servia/features/reservas/pages/resumen_reserva_page.dart';

import '../negocios/fakes.dart';
import 'fakes.dart';

class Escenario {
  Escenario({
    bool conSesion = false,
    String tipo = 'cliente',
    Object? errorPerfil,
    ReservasFalso? reservas,
  }) : sesion = SesionFalsa(conSesion: conSesion),
      perfil = PerfilFalso(tipo: tipo, error: errorPerfil),
      reservas = reservas ?? ReservasFalso(),
      disponibilidad = DisponibilidadFalsa(),
      registro = RegistroFalso();
  final SesionFalsa sesion;
  final PerfilFalso perfil;
  final ReservasFalso reservas;
  final DisponibilidadFalsa disponibilidad;
  final RegistroFalso registro;
  final llave = GlobalKey<NavigatorState>();
}

Future<void> avanzar(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Raíz real (AuthGate) con el detalle de un servicio encima, como cuando el
/// cliente entra con «Ver negocios sin iniciar sesión».
Future<void> abrirDetalle(WidgetTester tester, Escenario e) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(e.sesion.eventos.close);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: e.llave,
      home: AuthGate(
        authService: e.sesion,
        perfilService: e.perfil,
        registroClienteService: e.registro,
      ),
    ),
  );
  await avanzar(tester);
  e.llave.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => DetalleServicioPage(
        negocioId: 'abc123',
        servicioId: 's2',
        aceptaReservas: true,
        negocioNombre: 'Barbería Central',
        negociosService: DetalleServiceFalso(),
        disponibilidadService: e.disponibilidad,
        flujoReserva: FlujoReserva(
          authService: e.sesion,
          perfilService: e.perfil,
          reservasService: e.reservas,
          registroClienteService: e.registro,
        ),
      ),
    ),
  );
  await avanzar(tester);
}

Future<void> elegirHora(WidgetTester tester) async {
  await tester.tap(find.text('Reservar'));
  await avanzar(tester);
  await tester.tap(find.text('5'));
  await avanzar(tester);
  await tester.tap(find.text('11:30'));
  await avanzar(tester);
}

Future<void> iniciarSesion(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).at(0), 'ana@test.com');
  await tester.enterText(find.byType(TextField).at(1), '12345678');
  await tester.tap(find.text('Iniciar sesión'));
  await avanzar(tester);
}

void main() {
  testWidgets('sin sesión pide iniciar sesión y regresa al mismo punto de la reserva',
      (tester) async {
    final e = Escenario();
    await abrirDetalle(tester, e);
    await elegirHora(tester);
    expect(find.byType(DisponibilidadPage), findsNothing);
    expect(find.text(MensajesReservas.iniciarSesionParaReservar), findsOneWidget);
    expect(find.byType(ResumenReservaPage), findsNothing);
    expect(e.reservas.solicitudes, isEmpty);

    await iniciarSesion(tester);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(ResumenReservaPage), findsOneWidget);
    expect(find.text('Barbería Central'), findsOneWidget);
    expect(find.text('Z Corte'), findsOneWidget);
    expect(find.text('martes 5 de marzo de 2030'), findsOneWidget);
    expect(find.text('11:30'), findsOneWidget);

    await tester.ensureVisible(find.text(MensajesReservas.enviar));
    await tester.tap(find.text(MensajesReservas.enviar));
    await avanzar(tester);
    final s = e.reservas.solicitudes.single;
    expect((s.negocioId, s.servicioId), ('abc123', 's2'));
    expect(s.inicio, '2030-03-05T11:30:00-06:00');
    expect(find.byType(ConfirmacionReservaPage), findsOneWidget);
    expect(find.text('SRV-7KQ2MX'), findsOneWidget);
  });

  testWidgets('también regresa a la reserva si se registra desde ahí', (tester) async {
    final e = Escenario();
    await abrirDetalle(tester, e);
    await elegirHora(tester);
    await tester.tap(find.text('Regístrate'));
    await avanzar(tester);
    expect(find.byType(RegisterPage), findsOneWidget);
    for (final (i, texto) in [
      'Ana Pérez',
      '4771234567',
      'ana@test.com',
      '12345678',
    ].indexed) {
      await tester.enterText(find.byType(TextFormField).at(i), texto);
    }
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.tap(find.text('Crear cuenta'));
    await avanzar(tester);
    expect(e.registro.registros, 1);
    expect(find.byType(ResumenReservaPage), findsOneWidget);
    expect(find.text('11:30'), findsOneWidget);
  });

  testWidgets('una cuenta de negocio no puede reservar: se le avisa y se cierra su sesión',
      (tester) async {
    final e = Escenario(tipo: 'negocio');
    await abrirDetalle(tester, e);
    await elegirHora(tester);
    await iniciarSesion(tester);
    expect(find.byType(ResumenReservaPage), findsNothing);
    expect(find.text(MensajesAuth.soloClientes), findsWidgets);
    expect(e.sesion.cierres, greaterThanOrEqualTo(1));
    expect(e.sesion.usuarioActual, isNull);
    expect(e.reservas.solicitudes, isEmpty);
  });

  testWidgets('una cuenta desactivada (403) tampoco reserva y se cierra su sesión',
      (tester) async {
    final e = Escenario(errorPerfil: const ApiException(403, 'desactivada'));
    await abrirDetalle(tester, e);
    await elegirHora(tester);
    await iniciarSesion(tester);
    expect(find.byType(ResumenReservaPage), findsNothing);
    expect(find.text(MensajesAuth.cuentaDesactivada), findsWidgets);
    expect(e.sesion.usuarioActual, isNull);
  });

  testWidgets('si falla la red al verificar la cuenta avisa y se puede reintentar',
      (tester) async {
    final e = Escenario(errorPerfil: Exception('sin red'));
    await abrirDetalle(tester, e);
    await elegirHora(tester);
    await iniciarSesion(tester);
    expect(find.byType(ResumenReservaPage), findsNothing);
    expect(find.text(MensajesAuth.errorRed), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(e.reservas.solicitudes, isEmpty);
  });

  testWidgets('si cancela el inicio de sesión no se abre el resumen', (tester) async {
    final e = Escenario();
    await abrirDetalle(tester, e);
    await elegirHora(tester);
    await tester.tap(find.text('Cancelar'));
    await avanzar(tester);
    expect(find.byType(ResumenReservaPage), findsNothing);
    expect(find.byType(DetalleServicioPage), findsOneWidget);
    expect(e.sesion.inicios, 0);
  });

  testWidgets('con sesión de cliente va directo al resumen, sin pedir inicio de sesión',
      (tester) async {
    final e = Escenario(conSesion: true);
    await abrirDetalle(tester, e);
    await elegirHora(tester);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(ResumenReservaPage), findsOneWidget);
    expect(find.text('11:30'), findsOneWidget);
  });

  testWidgets('409: avisa que el horario ya no está libre y regresa a elegir horario',
      (tester) async {
    final e = Escenario(
      conSesion: true,
      reservas: ReservasFalso(error: const ApiException(409, 'ocupado')),
    );
    await abrirDetalle(tester, e);
    await elegirHora(tester);
    await tester.ensureVisible(find.text(MensajesReservas.enviar));
    await tester.tap(find.text(MensajesReservas.enviar));
    await avanzar(tester);
    expect(find.byType(ResumenReservaPage), findsNothing);
    expect(find.byType(DisponibilidadPage), findsOneWidget);
    expect(find.text(MensajesReservas.horarioOcupado), findsOneWidget);
    expect(e.disponibilidad.consultasDias, 2);
  });

  testWidgets('el aviso «muy pronto» ya no aparece al elegir una hora', (tester) async {
    final e = Escenario(conSesion: true);
    await abrirDetalle(tester, e);
    await elegirHora(tester);
    expect(find.text('La reserva estará disponible muy pronto.'), findsNothing);
  });
}
