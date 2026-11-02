import 'package:flutter/material.dart';

import '../data/negocios_service.dart';
import '../data/disponibilidad.dart';
import '../data/disponibilidad_service.dart';
import 'disponibilidad_page.dart';
import '../data/servicio.dart';
import '../formatos.dart';
import '../mensajes.dart';
import 'estados_consulta.dart';

enum _EstadoDetalle { cargando, error, listo }

class DetalleServicioPage extends StatefulWidget {
  const DetalleServicioPage({
    super.key,
    required this.negocioId,
    required this.servicioId,
    required this.aceptaReservas,
    this.negociosService,
    this.disponibilidadService,
    this.onSeleccionDisponibilidad,
  });
  final String negocioId;
  final String servicioId;
  final bool aceptaReservas;
  final NegociosService? negociosService;
  final DisponibilidadService? disponibilidadService;
  // Punto de enganche para MVP-18 / Movil#26; no crea reservas.
  final ValueChanged<SeleccionDisponibilidad>? onSeleccionDisponibilidad;

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

  Future<void> _abrirDisponibilidad() async {
    final seleccion = await Navigator.push<SeleccionDisponibilidad>(
      context,
      MaterialPageRoute(
        builder: (_) => DisponibilidadPage(
          negocioId: widget.negocioId,
          servicioId: widget.servicioId,
          service: widget.disponibilidadService,
        ),
      ),
    );
    if (!mounted || seleccion == null) return;
    if (widget.onSeleccionDisponibilidad != null) {
      widget.onSeleccionDisponibilidad!(seleccion);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(MensajesNegocios.reservaProxima)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget contenido;
    switch (_estado) {
      case _EstadoDetalle.cargando:
        contenido = const CargaNegocio();
      case _EstadoDetalle.error:
        contenido = ErrorNegocio(
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
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(servicio.nombre, style: Theme.of(context).textTheme.headlineSmall),
        if (servicio.descripcion != null) Text(servicio.descripcion!),
        const SizedBox(height: 16),
        Text(formatearPrecio(servicio.precio)),
        Text(formatearDuracion(servicio.duracionMin)),
        if (aceptaReservas) ...[
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onConsultar,
            child: const Text(MensajesNegocios.reservar),
          ),
        ],
      ],
    ),
  );
}
