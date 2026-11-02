import 'package:flutter/material.dart';

import '../mensajes.dart';
import 'estados_consulta.dart';

class PieLista extends StatelessWidget {
  const PieLista({
    super.key,
    required this.cargando,
    required this.error,
    required this.onReintentar,
  });
  final bool cargando;
  final Object? error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Padding(padding: EdgeInsets.all(24), child: CargaNegocio());
    }
    if (error != null) {
      return ErrorNegocio(
        mensaje: MensajesNegocios.mensajeDeErrorBusqueda(error!),
        onReintentar: MensajesNegocios.puedeReintentarBusqueda(error!)
            ? onReintentar
            : null,
      );
    }
    return const SizedBox.shrink();
  }
}
