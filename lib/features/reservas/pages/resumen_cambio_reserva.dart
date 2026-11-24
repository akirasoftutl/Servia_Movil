import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../mensajes.dart';

/// Datos ya formateados (zona America/Mexico_City) de una cita para el resumen.
class CitaResumen {
  const CitaResumen({required this.fecha, required this.hora});

  /// `martes 10 de noviembre de 2026`.
  final String fecha;

  /// `10:00`.
  final String hora;
}

/// «Confirmar cambio» (HU-C71 a C73): la cita de ahora, la nueva y el servicio
/// con su duración y precio. Los botones los pone la pantalla que lo usa.
class ResumenCambioReserva extends StatelessWidget {
  const ResumenCambioReserva({
    super.key,
    required this.actual,
    required this.nueva,
    required this.servicio,
    required this.detalleServicio,
    this.servicioAntes,
  });

  final CitaResumen actual;
  final CitaResumen nueva;
  final String servicio;

  /// `1 h 30 min · $300.50`.
  final String detalleServicio;

  /// Servicio y detalle de antes; solo si el cliente eligió otro servicio.
  final String? servicioAntes;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final suave = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget cita(String etiqueta, CitaResumen cita, {Key? key}) => Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(Espacios.l),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(etiqueta, style: textos.labelMedium?.copyWith(color: suave)),
              const SizedBox(height: Espacios.xs),
              Text(cita.fecha, style: textos.titleMedium),
              Text(cita.hora, style: textos.bodyLarge),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(MensajesReservas.confirmarCambio, style: textos.titleLarge),
        const SizedBox(height: Espacios.m),
        cita(MensajesReservas.ahoraEs, actual),
        const SizedBox(height: Espacios.m),
        cita(
          MensajesReservas.nuevaCita,
          nueva,
          key: const ValueKey('tarjeta-cita-nueva'),
        ),
        const SizedBox(height: Espacios.m),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Espacios.l),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    MensajesReservas.servicioDeLaCita,
                    style: textos.labelMedium?.copyWith(color: suave),
                  ),
                  const SizedBox(height: Espacios.xs),
                  Text(servicio, style: textos.titleMedium),
                  Text(detalleServicio, style: textos.bodyMedium),
                  if (servicioAntes != null) ...[
                    const SizedBox(height: Espacios.s),
                    Text(
                      '${MensajesReservas.servicioAntes}: $servicioAntes',
                      style: textos.bodySmall?.copyWith(color: suave),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
