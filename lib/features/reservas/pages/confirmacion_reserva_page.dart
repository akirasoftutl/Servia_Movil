import 'package:flutter/material.dart';

import '../../negocios/formatos.dart';
import '../data/reserva_creada.dart';
import '../fechas_reserva.dart';
import '../mensajes.dart';

/// Confirmación de la solicitud enviada: folio, estado Pendiente y plazo (MVP-18).
class ConfirmacionReservaPage extends StatelessWidget {
  const ConfirmacionReservaPage({
    super.key,
    required this.reserva,
    required this.negocioNombre,
    required this.servicioNombre,
    required this.fecha,
    required this.hora,
  });

  final ReservaCreada reserva;
  final String negocioNombre;
  final String servicioNombre;
  final String fecha;
  final String hora;

  void _volver(BuildContext context) =>
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (salio, _) {
      if (!salio) _volver(context);
    },
    child: Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(MensajesReservas.confirmacionTitulo),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(
              reserva.folio,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            subtitle: const Text(MensajesReservas.folio),
          ),
          const ListTile(
            title: Text(MensajesReservas.estadoPendiente),
            subtitle: Text(MensajesReservas.estado),
          ),
          const ListTile(
            leading: Icon(Icons.schedule),
            title: Text(MensajesReservas.avisoDosHoras),
          ),
          const Divider(),
          ListTile(
            title: Text(servicioNombre),
            subtitle: Text(
              '$negocioNombre\n${formatearFechaLarga(fecha)}, $hora\n'
              '${formatearDuracion(reserva.duracionMin)} · '
              '${formatearPrecio(reserva.precio)}',
            ),
          ),
          ListTile(
            title: FilledButton(
              onPressed: () => _volver(context),
              child: const Text(MensajesReservas.volverAlInicio),
            ),
          ),
        ],
      ),
    ),
  );
}
