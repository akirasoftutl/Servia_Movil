import 'package:flutter/material.dart';

import 'data/negocios_service.dart';
import 'mensajes.dart';
import 'pages/perfil_negocio_page.dart';

Route<dynamic>? generarRutaNegocios(RouteSettings ajustes) {
  final coincidencia = RegExp(r'^/negocios/([^/]+)$')
      .firstMatch(ajustes.name ?? '');
  if (coincidencia == null) return null;
  final id = coincidencia.group(1)!;
  if (!esIdValido(id)) return null;
  return MaterialPageRoute<void>(
    settings: ajustes,
    builder: (_) => PerfilNegocioPage(negocioId: id),
  );
}

Route<dynamic> generarRutaNoDisponible(RouteSettings ajustes) =>
    MaterialPageRoute<void>(
      settings: ajustes,
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text(MensajesNegocios.tituloPerfil)),
        body: const Center(child: Text(MensajesNegocios.noDisponible)),
      ),
    );
