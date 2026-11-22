import 'package:flutter/material.dart';

import '../auth/data/auth_service.dart';
import 'data/reservas_service.dart';
import 'pages/detalle_reserva_page.dart';

/// Ruta reutilizable por la lista y por futuros avisos (MVP-20, D4).
Route<dynamic>? generarRutaReservas(
  RouteSettings ajustes, {
  AuthService? authService,
  ReservasService? reservasService,
}) {
  final coincidencia = RegExp(r'^/reservas/([^/]+)$')
      .firstMatch(ajustes.name ?? '');
  if (coincidencia == null) return null;
  return MaterialPageRoute<void>(
    settings: ajustes,
    builder: (_) => DetalleReservaPage(
      id: coincidencia.group(1)!,
      authService: authService,
      reservasService: reservasService,
    ),
  );
}
