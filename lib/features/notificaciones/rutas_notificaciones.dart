import 'package:flutter/material.dart';

import 'data/servicio_push.dart';
import 'pages/avisos_page.dart';

/// Ruta de la lista de avisos; se encadena con las de reservas y negocios en
/// `MaterialApp.onGenerateRoute`.
Route<dynamic>? generarRutaNotificaciones(
  RouteSettings ajustes, {
  ServicioPush? push,
}) {
  if (ajustes.name != '/avisos') return null;
  final pushDeLaRuta = ajustes.arguments is ServicioPush
      ? ajustes.arguments as ServicioPush
      : push;
  return MaterialPageRoute<void>(
    settings: ajustes,
    builder: (_) => AvisosPage(push: pushDeLaRuta),
  );
}
