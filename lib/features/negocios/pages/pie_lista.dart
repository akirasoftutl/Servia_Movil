import 'package:flutter/material.dart';

import '../../../core/widgets/estados.dart';
import '../mensajes.dart';

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
      return const EstadoCargando(compacto: true);
    }
    if (error != null) {
      return EstadoError(
        compacto: true,
        mensaje: MensajesNegocios.mensajeDeErrorBusqueda(error!),
        onReintentar: MensajesNegocios.puedeReintentarBusqueda(error!)
            ? onReintentar
            : null,
      );
    }
    return const SizedBox.shrink();
  }
}
