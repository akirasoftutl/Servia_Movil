import 'package:material_ui/material_ui.dart';

import '../../../core/theme/colores_servia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/etiqueta_estado.dart';
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
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final textos = tema.textTheme;
    final semanticos = ColoresSemanticos.de(context);
    return PopScope(
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
          padding: const EdgeInsets.fromLTRB(
            Espacios.l,
            Espacios.l,
            Espacios.l,
            Espacios.xxl,
          ),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Espacios.xl),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: Medidas.iconoEstado,
                      color: semanticos.exito,
                    ),
                    const SizedBox(height: Espacios.m),
                    Text(MensajesReservas.folio, style: textos.bodySmall),
                    const SizedBox(height: Espacios.xs),
                    SelectableText(
                      reserva.folio,
                      textAlign: TextAlign.center,
                      style: textos.headlineMedium?.copyWith(
                        letterSpacing: 1,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: Espacios.l),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: Espacios.s,
                      runSpacing: Espacios.xs,
                      children: [
                        Text(MensajesReservas.estado, style: textos.bodyMedium),
                        const EtiquetaEstado(
                          texto: MensajesReservas.estadoPendiente,
                          tono: TonoEstado.aviso,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Espacios.l),
            const Aviso(
              tipo: TipoAviso.informacion,
              icono: Icons.schedule,
              texto: MensajesReservas.avisoDosHoras,
            ),
            const SizedBox(height: Espacios.l),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Espacios.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(servicioNombre, style: textos.titleMedium),
                    const SizedBox(height: Espacios.xs),
                    Text(
                      '$negocioNombre\n${formatearFechaLarga(fecha)}, $hora\n'
                      '${formatearDuracion(reserva.duracionMin)} · '
                      '${formatearPrecio(reserva.precio)}',
                      style: textos.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Espacios.xl),
            FilledButton(
              onPressed: () => _volver(context),
              child: const Text(MensajesReservas.volverAlInicio),
            ),
          ],
        ),
      ),
    );
  }
}
