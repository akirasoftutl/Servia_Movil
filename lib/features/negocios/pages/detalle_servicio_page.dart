import 'package:flutter/material.dart';

import '../../../core/widgets/estados.dart';
import '../../reservas/flujo_reserva.dart';
import '../../reservas/mensajes.dart';
import '../../reservas/resultado_reserva.dart';
import '../data/disponibilidad.dart';
import '../data/disponibilidad_service.dart';
import '../data/negocios_service.dart';
import '../data/servicio.dart';
import '../formatos.dart';
import '../mensajes.dart';
import 'disponibilidad_page.dart';

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
    this.ahora = DateTime.now,
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
  // Reloj que se pasa a la disponibilidad; por defecto, la hora real.
  final DateTime Function() ahora;

  @override
  State<DetalleServicioPage> createState() => _DetalleServicioPageState();
}

class _DetalleServicioPageState extends State<DetalleServicioPage> {
  late final NegociosService _service;
  Servicio? _servicio;
  Object? _error;
  _EstadoDetalle _estado = _EstadoDetalle.cargando;

  double _desplazamientoY = 0;
  bool _arrastrando = false;

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
            ahora: widget.ahora,
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

  void _onVerticalDragStart(DragStartDetails details) {
    setState(() => _arrastrando = true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _desplazamientoY = (_desplazamientoY + details.delta.dy).clamp(0.0, 700.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocidad = details.primaryVelocity ?? 0;
    if (_desplazamientoY > 110 || velocidad > 650) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _arrastrando = false;
      _desplazamientoY = 0;
    });
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
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        bottom: false,
        // Ahora todo el contenedor responde al arrastre hacia abajo
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: _onVerticalDragStart,
          onVerticalDragUpdate: _onVerticalDragUpdate,
          onVerticalDragEnd: _onVerticalDragEnd,
          child: AnimatedContainer(
            duration: _arrastrando
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _desplazamientoY, 0),
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Cabecera visual con manejador + botón 'X'
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 16, 8),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF111827),
                            size: 26,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: contenido),
              ],
            ),
          ),
        ),
      ),
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
    final tieneDescripcion =
        servicio.descripcion != null && servicio.descripcion!.trim().isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            // ClampingScrollPhysics permite que al deslizar hacia abajo desde arriba
            // el gesto pase directo al GestureDetector para cerrar la tarjeta
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Título grande en negrita
                Text(
                  servicio.nombre,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.18,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 12),

                // 2. Indicador de si acepta reservas (arriba de la descripción)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: aceptaReservas
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        aceptaReservas
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 15,
                        color: aceptaReservas
                            ? const Color(0xFF15803D)
                            : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        aceptaReservas
                            ? MensajesNegocios.aceptaReservas
                            : MensajesNegocios.noAceptaReservas,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: aceptaReservas
                              ? const Color(0xFF15803D)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Descripción del servicio (si existe)
                if (tieneDescripcion) ...[
                  const SizedBox(height: 18),
                  Text(
                    servicio.descripcion!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF374151),
                      height: 1.45,
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 18),

                // 4. Duración mencionada debajo de la descripción
                const Text(
                  'Duración',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatearDuracion(servicio.duracionMin),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Barra inferior fija con precio + duración a la izquierda y botón píldora a la derecha
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              // El precio y el botón comparten línea mientras haya espacio;
              // con texto muy grande el botón baja en lugar de estrangular
              // al precio y provocar un desbordamiento vertical.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatearPrecio(servicio.precio),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatearDuracion(servicio.duracionMin),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  if (aceptaReservas)
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: ElevatedButton(
                        onPressed: onConsultar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F0F0F),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text(MensajesNegocios.reservar),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
