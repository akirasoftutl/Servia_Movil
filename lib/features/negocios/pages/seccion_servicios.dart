import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../data/negocios_service.dart';
import '../data/servicio.dart';
import '../formatos.dart';
import '../mensajes.dart';
import 'detalle_servicio_page.dart';

enum _EstadoServicios { cargando, error, vacio, listo }

class SeccionServicios extends StatefulWidget {
  const SeccionServicios({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    required this.aceptaReservas,
    required this.service,
  });
  final String negocioId;
  final String negocioNombre;
  final bool aceptaReservas;
  final NegociosService service;

  @override
  State<SeccionServicios> createState() => _SeccionServiciosState();
}

class _SeccionServiciosState extends State<SeccionServicios> {
  List<Servicio>? _servicios;
  Object? _error;
  _EstadoServicios _estado = _EstadoServicios.cargando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _estado = _EstadoServicios.cargando;
      _error = null;
    });
    try {
      final servicios = await widget.service.obtenerServicios(widget.negocioId);
      if (!mounted) return;
      setState(() {
        _servicios = servicios;
        _estado = servicios.isEmpty
            ? _EstadoServicios.vacio
            : _EstadoServicios.listo;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _estado = _EstadoServicios.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget contenido;
    switch (_estado) {
      case _EstadoServicios.cargando:
        contenido = const EstadoCargando(compacto: true);
      case _EstadoServicios.error:
        contenido = EstadoError(
          compacto: true,
          mensaje: MensajesNegocios.mensajeDeError(_error!),
          onReintentar: MensajesNegocios.puedeReintentar(_error!)
              ? _cargar
              : null,
        );
      case _EstadoServicios.vacio:
        contenido = const EstadoVacio(
          compacto: true,
          icono: Icons.content_cut,
          mensaje: MensajesNegocios.sinServicios,
        );
      case _EstadoServicios.listo:
        final servicios = _servicios!;
        contenido = Column(
          children: [
            for (var i = 0; i < servicios.length; i++) ...[
              if (i > 0)
                const Divider(indent: Espacios.l, endIndent: Espacios.l),
              _FilaServicio(
                servicio: servicios[i],
                onAbrir: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DetalleServicioPage(
                      negocioId: widget.negocioId,
                      servicioId: servicios[i].id,
                      aceptaReservas: widget.aceptaReservas,
                      negocioNombre: widget.negocioNombre,
                      negociosService: widget.service,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MensajesNegocios.servicios,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Espacios.m),
        SizedBox(
          width: double.infinity,
          child: Card(child: contenido),
        ),
      ],
    );
  }
}

class _FilaServicio extends StatelessWidget {
  const _FilaServicio({required this.servicio, required this.onAbrir});
  final Servicio servicio;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListTile(
      onTap: onAbrir,
      title: Text(servicio.nombre),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: Espacios.xs),
        child: Row(
          children: [
            Icon(
              Icons.schedule,
              size: 16,
              color: tema.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Espacios.xs),
            Flexible(child: Text(formatearDuracion(servicio.duracionMin))),
          ],
        ),
      ),
      trailing: Text(
        formatearPrecio(servicio.precio),
        style: tema.textTheme.titleMedium?.copyWith(
          color: tema.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
