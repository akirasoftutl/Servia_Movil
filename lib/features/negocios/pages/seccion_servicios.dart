import 'package:flutter/material.dart';

import '../data/negocios_service.dart';
import '../data/servicio.dart';
import '../formatos.dart';
import '../mensajes.dart';
import 'detalle_servicio_page.dart';
import 'estados_consulta.dart';

enum _EstadoServicios { cargando, error, vacio, listo }

class SeccionServicios extends StatefulWidget {
  const SeccionServicios({
    super.key,
    required this.negocioId,
    required this.aceptaReservas,
    required this.service,
  });
  final String negocioId;
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
        contenido = const CargaNegocio();
      case _EstadoServicios.error:
        contenido = ErrorNegocio(
          mensaje: MensajesNegocios.mensajeDeError(_error!),
          onReintentar: MensajesNegocios.puedeReintentar(_error!)
              ? _cargar
              : null,
        );
      case _EstadoServicios.vacio:
        contenido = const Text(MensajesNegocios.sinServicios);
      case _EstadoServicios.listo:
        contenido = Column(
          children: [
            for (final servicio in _servicios!)
              _FilaServicio(
                servicio: servicio,
                onAbrir: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => DetalleServicioPage(
                      negocioId: widget.negocioId,
                      servicioId: servicio.id,
                      aceptaReservas: widget.aceptaReservas,
                      negociosService: widget.service,
                    ),
                  ),
                ),
              ),
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
        contenido,
      ],
    );
  }
}

class _FilaServicio extends StatelessWidget {
  const _FilaServicio({required this.servicio, required this.onAbrir});
  final Servicio servicio;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: onAbrir,
    title: Text(servicio.nombre),
    subtitle: Text(formatearDuracion(servicio.duracionMin)),
    trailing: Text(formatearPrecio(servicio.precio)),
  );
}
