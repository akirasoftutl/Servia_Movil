import 'package:flutter/material.dart';

import '../auth/data/auth_service.dart';
import '../auth/data/perfil_service.dart';
import '../auth/data/registro_cliente_service.dart';
import '../auth/pages/login_page.dart';
import '../negocios/data/disponibilidad.dart';
import '../negocios/data/servicio.dart';
import 'data/reservas_service.dart';
import 'pages/resumen_reserva_page.dart';
import 'resultado_reserva.dart';

/// De la hora elegida al resumen de la reserva (MVP-18): si no hay sesión pide
/// iniciarla y regresa al mismo punto (mismo negocio, servicio, fecha y hora).
class FlujoReserva {
  const FlujoReserva({
    this.authService,
    this.perfilService,
    this.reservasService,
    this.registroClienteService,
    this.ahora = DateTime.now,
  });

  final AuthService? authService;
  final PerfilService? perfilService;
  final ReservasService? reservasService;
  final RegistroClienteService? registroClienteService;
  final DateTime Function() ahora;

  Future<ResultadoReserva> iniciar(
    BuildContext context, {
    required String negocioNombre,
    required Servicio servicio,
    required SeleccionDisponibilidad seleccion,
  }) async {
    final auth = authService ?? AuthService();
    if (auth.usuarioActual == null) {
      final inicio = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPage(
            regresarAlIniciar: true,
            authService: auth,
            perfilService: perfilService,
            registroClienteService: registroClienteService,
          ),
        ),
      );
      if (inicio != true) return ResultadoReserva.cancelada;
      if (!context.mounted) return ResultadoReserva.cancelada;
    }
    final resultado = await Navigator.push<ResultadoReserva>(
      context,
      MaterialPageRoute(
        builder: (_) => ResumenReservaPage(
          negocioId: seleccion.negocioId,
          negocioNombre: negocioNombre,
          servicio: servicio,
          fecha: seleccion.fecha,
          hora: seleccion.hora,
          authService: auth,
          perfilService: perfilService,
          reservasService: reservasService,
          ahora: ahora,
        ),
      ),
    );
    return resultado ?? ResultadoReserva.cancelada;
  }
}
