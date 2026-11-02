import 'package:flutter/material.dart';

import '../data/negocio_resumen.dart';
import '../data/negocios_service.dart';
import '../mensajes.dart';

class TarjetaNegocio extends StatelessWidget {
  const TarjetaNegocio({
    super.key,
    required this.negocio,
    required this.categoria,
  });
  final NegocioResumen negocio;
  final String categoria;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(negocio.nombre, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(categoria),
        Text(
          negocio.aceptaReservas
              ? MensajesNegocios.aceptaReservas
              : MensajesNegocios.noAceptaReservas,
        ),
      ],
    ),
    onTap: () {
      if (esIdValido(negocio.id)) {
        Navigator.pushNamed(context, '/negocios/${negocio.id}');
      }
    },
  );
}
