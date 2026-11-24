import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../data/negocios_service.dart';
import '../data/servicio.dart';
import '../formatos.dart';
import '../mensajes.dart';
import 'categorias_servicio.dart';
import 'detalle_servicio_page.dart';
import 'fotos_negocio.dart';
import 'imagenes_servicio.dart';

enum _EstadoServicios { cargando, error, vacio, listo }

class SeccionServicios extends StatefulWidget {
  const SeccionServicios({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    required this.aceptaReservas,
    required this.service,
    this.proveedorImagenes = NetworkImage.new,
  });

  final ProveedorImagenNegocio proveedorImagenes;
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

  /// Categoría de catálogo elegida en el filtro (`null` es «Todas»). Vive en
  /// el estado de la sección: al volver del detalle se conserva.
  String? _categoriaId;

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

  void _abrirServicio(Servicio servicio) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DetalleServicioPage(
          negocioId: widget.negocioId,
          servicioId: servicio.id,
          aceptaReservas: widget.aceptaReservas,
          negocioNombre: widget.negocioNombre,
          negociosService: widget.service,
          proveedorImagenes: widget.proveedorImagenes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget contenido;
    switch (_estado) {
      case _EstadoServicios.cargando:
        contenido = const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: EstadoCargando(compacto: true),
        );
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
        final todos = _servicios!;
        final categorias = categoriasDeCatalogo(todos);
        // Si la elegida ya no existe, se vuelve a «Todas».
        final categoriaId = categorias.any((c) => c.id == _categoriaId)
            ? _categoriaId
            : null;
        final servicios = categoriaId == null
            ? todos
            : [
                for (final s in todos)
                  if (s.categoriaServicio?.id == categoriaId) s,
              ];
        contenido = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (categorias.isNotEmpty) ...[
              FiltroCategoriasServicio(
                categorias: categorias,
                categoriaId: categoriaId,
                onCategoria: (id) => setState(() => _categoriaId = id),
              ),
              const SizedBox(height: Espacios.l),
            ],
            for (var i = 0; i < servicios.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _TarjetaServicio(
                servicio: servicios[i],
                aceptaReservas: widget.aceptaReservas,
                proveedorImagenes: widget.proveedorImagenes,
                onAbrir: () => _abrirServicio(servicios[i]),
              ),
            ],
          ],
        );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            MensajesNegocios.servicios,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          contenido,
        ],
      ),
    );
  }
}

class _TarjetaServicio extends StatelessWidget {
  const _TarjetaServicio({
    required this.servicio,
    required this.aceptaReservas,
    required this.proveedorImagenes,
    required this.onAbrir,
  });

  final ProveedorImagenNegocio proveedorImagenes;
  final Servicio servicio;
  final bool aceptaReservas;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onAbrir,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Miniatura de la primera imagen (HU-C32); sin imágenes no hay hueco
              if (servicio.imagenes.isNotEmpty &&
                  MiniaturaServicio.cabe(context)) ...[
                MiniaturaServicio(
                  servicioId: servicio.id,
                  imagen: servicio.imagenes.first,
                  proveedor: proveedorImagenes,
                ),
                const SizedBox(width: Espacios.l),
              ],
              // Información izquierda: Título, duración y precio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      servicio.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                        height: 1.25,
                      ),
                    ),
                    if (servicio.categoria != null) ...[
                      const SizedBox(height: Espacios.xs),
                      CategoriaDelServicio(
                        key: Key('categoria-servicio-${servicio.id}'),
                        servicio: servicio,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      formatearDuracion(servicio.duracionMin),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      formatearPrecio(servicio.precio),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Botón tipo píldora a la derecha ("Reservar" o "Ver")
              OutlinedButton(
                onPressed: onAbrir,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  backgroundColor: Colors.white,
                  side: const BorderSide(
                    color: Color(0xFFD1D5DB),
                    width: 1,
                  ),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(aceptaReservas ? 'Reservar' : 'Ver detalle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}