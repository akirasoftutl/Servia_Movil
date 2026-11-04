import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../data/negocios_service.dart';
import '../data/disponibilidad.dart';
import '../data/disponibilidad_service.dart';
import 'disponibilidad_page.dart';
import '../data/servicio.dart';
import '../formatos.dart';
import '../mensajes.dart';
import '../../reservas/flujo_reserva.dart';
import '../../reservas/mensajes.dart';
import '../../reservas/resultado_reserva.dart';

enum _EstadoDetalle { cargando, error, listo }

class DetalleServicioPage extends StatefulWidget {
  const DetalleServicioPage({
    super.key,
    required this.negocioId,
    required this.servicioId,
    required this.aceptaReservas,
    required this.negocioNombre,
    this.negociosService,
    this.disponibilidadService,
    this.onSeleccionDisponibilidad,
    this.flujoReserva = const FlujoReserva(),
  });
  final String negocioId;
  final String servicioId;
  final bool aceptaReservas;
  final String negocioNombre;
  final NegociosService? negociosService;
  final DisponibilidadService? disponibilidadService;
  // Sustituye el flujo de reserva (MVP-18); sin él se abre el resumen.
  final ValueChanged<SeleccionDisponibilidad>? onSeleccionDisponibilidad;
  final FlujoReserva flujoReserva;

  @override
  State<DetalleServicioPage> createState() => _DetalleServicioPageState();
}

class _DetalleServicioPageState extends State<DetalleServicioPage> {
  late final NegociosService _service;
  Servicio? _servicio;
  Object? _error;
  _EstadoDetalle _estado = _EstadoDetalle.cargando;

  @override
  void initState() {
    super.initState();
    _service = widget.negociosService ?? NegociosService();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _estado = _EstadoDetalle.cargando;
      _error = null;
    });
    try {
      final servicio = await _service.obtenerServicio(
        widget.negocioId,
        widget.servicioId,
      );
      if (!mounted) return;
      setState(() {
        _servicio = servicio;
        _estado = _EstadoDetalle.listo;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _estado = _EstadoDetalle.error;
      });
    }
  }

  Future<SeleccionDisponibilidad?> _elegirHorario({String? aviso}) =>
      Navigator.push<SeleccionDisponibilidad>(
        context,
        MaterialPageRoute(
          builder: (_) => DisponibilidadPage(
            negocioId: widget.negocioId,
            servicioId: widget.servicioId,
            service: widget.disponibilidadService,
            aviso: aviso,
          ),
        ),
      );

  // Elegir horario y reservar; si el horario se ocupó (409) vuelve a elegir.
  Future<void> _abrirDisponibilidad() async {
    String? aviso;
    while (true) {
      final seleccion = await _elegirHorario(aviso: aviso);
      if (!mounted || seleccion == null) return;
      if (widget.onSeleccionDisponibilidad != null) {
        widget.onSeleccionDisponibilidad!(seleccion);
        return;
      }
      final resultado = await widget.flujoReserva.iniciar(
        context,
        negocioNombre: widget.negocioNombre,
        servicio: _servicio!,
        seleccion: seleccion,
      );
      if (!mounted || resultado != ResultadoReserva.horarioOcupado) return;
      aviso = MensajesReservas.horarioOcupado;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget contenido;
    switch (_estado) {
      case _EstadoDetalle.cargando:
        contenido = const EstadoCargando();
      case _EstadoDetalle.error:
        contenido = EstadoError(
          mensaje: MensajesNegocios.mensajeDeError(_error!, esServicio: true),
          onReintentar: MensajesNegocios.puedeReintentar(_error!)
              ? _cargar
              : null,
        );
      case _EstadoDetalle.listo:
        contenido = _ContenidoServicio(
          servicio: _servicio!,
          aceptaReservas: widget.aceptaReservas,
          onConsultar: _abrirDisponibilidad,
        );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(MensajesNegocios.detalleServicio)),
      body: contenido,
    );
  }
}

class _ContenidoServicio extends StatelessWidget {
  const _ContenidoServicio({
    required this.servicio,
    required this.aceptaReservas,
    required this.onConsultar,
  });
  final VoidCallback onConsultar;
  final Servicio servicio;
  final bool aceptaReservas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final textos = tema.textTheme;
    final c = tema.colorScheme;
    final detalle = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Espacios.l,
        Espacios.s,
        Espacios.l,
        Espacios.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(servicio.nombre, style: textos.headlineSmall),
          if (servicio.descripcion != null) ...[
            const SizedBox(height: Espacios.s),
            Text(
              servicio.descripcion!,
              style: textos.bodyLarge?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: Espacios.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Espacios.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatearPrecio(servicio.precio),
                    style: textos.headlineMedium?.copyWith(color: c.primary),
                  ),
                  const SizedBox(height: Espacios.s),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 20, color: c.onSurfaceVariant),
                      const SizedBox(width: Espacios.s),
                      Flexible(
                        child: Text(
                          formatearDuracion(servicio.duracionMin),
                          style: textos.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (!aceptaReservas) return detalle;
    // La acción principal queda fija abajo, siempre a la mano.
    return Column(
      children: [
        Expanded(child: detalle),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(top: BorderSide(color: c.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Espacios.l,
                Espacios.m,
                Espacios.l,
                Espacios.m,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onConsultar,
                  child: const Text(MensajesNegocios.reservar),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
