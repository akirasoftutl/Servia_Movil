import 'package:flutter/material.dart';

import 'pages/favoritos_page.dart';

/// Ruta de «Mis favoritos»; se encadena con las demás en
/// `MaterialApp.onGenerateRoute`.
Route<dynamic>? generarRutaFavoritos(RouteSettings ajustes) {
  if (ajustes.name != '/favoritos') return null;
  return MaterialPageRoute<void>(
    settings: ajustes,
    builder: (_) => const FavoritosPage(),
  );
}
