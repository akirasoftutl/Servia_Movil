import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../data/negocio.dart';
import '../data/negocios_service.dart';
import '../formatos.dart';
import '../mensajes.dart';
import 'fotos_negocio.dart';
import 'miniatura_negocio.dart';
import 'seccion_servicios.dart';

enum _EstadoPerfil { cargando, error, listo }

class PerfilNegocioPage extends StatefulWidget {
  const PerfilNegocioPage({
    super.key,
    required this.negocioId,
    this.negociosService,
    ProveedorImagenNegocio? proveedorFotos,
  }) : proveedorFotos = proveedorFotos ?? NetworkImage.new;

  final String negocioId;
  final NegociosService? negociosService;
  final ProveedorImagenNegocio proveedorFotos;

  @override
  State<PerfilNegocioPage> createState() => _PerfilNegocioPageState();
}

class _PerfilNegocioPageState extends State<PerfilNegocioPage> {
  late final NegociosService _service;
  Negocio? _negocio;
  String? _categoria;
  Object? _error;
  _EstadoPerfil _estado = _EstadoPerfil.cargando;

  @override
  void initState() {
    super.initState();
    _service = widget.negociosService ?? NegociosService();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _estado = _EstadoPerfil.cargando;
      _error = null;
    });
    try {
      final negocio = await _service.obtenerNegocio(widget.negocioId);
      if (!mounted) return;
      setState(() {
        _negocio = negocio;
        _categoria = negocio.categoriaId;
        _estado = _EstadoPerfil.listo;
      });
      _cargarCategoria(negocio.categoriaId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _estado = _EstadoPerfil.error;
      });
    }
  }

  Future<void> _cargarCategoria(String categoriaId) async {
    try {
      final categorias = await _service.obtenerCategorias();
      if (!mounted) return;
      for (final categoria in categorias) {
        if (categoria.id == categoriaId) {
          setState(() => _categoria = categoria.nombre);
          return;
        }
      }
    } catch (_) {
      if (!mounted) return;
      // D2: el catálogo no impide consultar el perfil.
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_estado) {
      case _EstadoPerfil.cargando:
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(MensajesNegocios.tituloPerfil),
          ),
          body: const EstadoCargando(),
        );
      case _EstadoPerfil.error:
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text(MensajesNegocios.tituloPerfil),
          ),
          body: EstadoError(
            mensaje: MensajesNegocios.mensajeDeError(_error!),
            onReintentar: MensajesNegocios.puedeReintentar(_error!)
                ? _cargar
                : null,
          ),
        );
      case _EstadoPerfil.listo:
        return Scaffold(
          backgroundColor: Colors.white,
          body: _ContenidoPerfil(
            negocio: _negocio!,
            categoria: _categoria!,
            service: _service,
            proveedorFotos: widget.proveedorFotos,
          ),
        );
    }
  }
}

class _ContenidoPerfil extends StatelessWidget {
  const _ContenidoPerfil({
    required this.negocio,
    required this.categoria,
    required this.service,
    required this.proveedorFotos,
  });

  final NegociosService service;
  final Negocio negocio;
  final String categoria;
  final ProveedorImagenNegocio proveedorFotos;

  @override
  Widget build(BuildContext context) {
    final fotos = negocio.fotos;
    final tienePortada = fotos.portada != null;
    final totalFotos = (tienePortada ? 1 : 0) + fotos.galeria.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Espacios.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera superior con foto inmersiva + botón circular atrás (o barra superior limpia si no hay foto)
          if (tienePortada)
            SizedBox(
              height: 290,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PortadaNegocio(
                    foto: fotos.portada!,
                    proveedor: proveedorFotos,
                  ),
                  // Botón circular blanco superior izquierdo para regresar
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 10,
                    left: 16,
                    child: _BotonCircularAtras(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  // Indicador "1/N" abajo a la derecha si hay varias fotos
                  if (totalFotos > 1)
                    Positioned(
                      bottom: 34,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '1/$totalFotos',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    _BotonCircularAtras(
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    MiniaturaNegocio(nombre: negocio.nombre, tamano: 42),
                  ],
                ),
              ),
            ),
// Contenedor blanco con esquinas superiores redondeadas superpuesto a la imagen
          Transform.translate(
            offset: Offset(0, tienePortada ? -22 : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EncabezadoNegocio(
                        negocio: negocio,
                        categoria: categoria,
                        mostrarMiniatura: !tienePortada,
                      ),

                      // Galería de fotos si existe
                      if (fotos.galeria.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        GaleriaFotosNegocio(
                          fotos: fotos.galeria,
                          proveedor: proveedorFotos,
                        ),
                      ],

                      // Datos de contacto adicionales (teléfono / correo)
                      const SizedBox(height: 24),
                      _ContactoNegocio(negocio: negocio),

                      // Horario semanal
                      const SizedBox(height: 24),
                      _HorarioSemanal(horario: negocio.horario),
                    ],
                  ),
                ),

                SeccionServicios(
                  negocioId: negocio.id,
                  negocioNombre: negocio.nombre,
                  aceptaReservas: negocio.aceptaReservas,
                  service: service,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonCircularAtras extends StatelessWidget {
  const _BotonCircularAtras({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF111827),
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Bloque superior: Título grande, categoría, estado de reservas, píldora de dirección y "Acerca de"
class _EncabezadoNegocio extends StatefulWidget {
  const _EncabezadoNegocio({
    required this.negocio,
    required this.categoria,
    this.mostrarMiniatura = false,
  });

  final Negocio negocio;
  final String categoria;
  final bool mostrarMiniatura;

  @override
  State<_EncabezadoNegocio> createState() => _EncabezadoNegocioState();
}

class _EncabezadoNegocioState extends State<_EncabezadoNegocio> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final negocio = widget.negocio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nombre del negocio
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.mostrarMiniatura) ...[
              MiniaturaNegocio(nombre: negocio.nombre, tamano: 52),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    negocio.nombre,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      height: 1.15,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.categoria,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Fila de estado de reservas con ícono de reloj en verde (estilo "Abierto hasta..." de la referencia)
        Row(
          children: [
            Icon(
              negocio.aceptaReservas
                  ? Icons.access_time_rounded
                  : Icons.info_outline_rounded,
              size: 18,
              color: negocio.aceptaReservas
                  ? const Color(0xFF16A34A)
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              negocio.aceptaReservas
                  ? MensajesNegocios.aceptaReservas
                  : MensajesNegocios.noAceptaReservas,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: negocio.aceptaReservas
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),

        // Píldora gris suave con la dirección (igual al chip de ubicación de la imagen)
        if (negocio.direccionTexto != null &&
            negocio.direccionTexto!.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  size: 18,
                  color: Color(0xFF111827),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    negocio.direccionTexto!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Sección "Acerca de" con descripción y botón "Leer más" si es larga
        if (negocio.descripcion != null &&
            negocio.descripcion!.trim().isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'Acerca de',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            negocio.descripcion!,
            maxLines: _expandido ? null : 3,
            overflow: _expandido ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Color(0xFF374151),
            ),
          ),
          if (negocio.descripcion!.length > 110)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => setState(() => _expandido = !_expandido),
                child: Text(
                  _expandido ? 'Leer menos' : 'Leer más',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ContactoNegocio extends StatelessWidget {
  const _ContactoNegocio({required this.negocio});
  final Negocio negocio;

  @override
  Widget build(BuildContext context) {
    // La dirección ya se muestra destacada arriba en su píldora; aquí dejamos teléfono y correo
    final filas = [
      if (negocio.telefono != null)
        _FilaContacto(Icons.phone_outlined, negocio.telefono!),
      if (negocio.correoContacto != null)
        _FilaContacto(Icons.mail_outline, negocio.correoContacto!),
    ];
    if (filas.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: filas),
    );
  }
}

class _FilaContacto extends StatelessWidget {
  const _FilaContacto(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icono, size: 20, color: const Color(0xFF111827)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _HorarioSemanal extends StatelessWidget {
  const _HorarioSemanal({required this.horario});
  final Map<String, HorarioDia?> horario;

  static const _clavesPorWeekday = <int, String>{
    DateTime.monday: 'lunes',
    DateTime.tuesday: 'martes',
    DateTime.wednesday: 'miercoles',
    DateTime.thursday: 'jueves',
    DateTime.friday: 'viernes',
    DateTime.saturday: 'sabado',
    DateTime.sunday: 'domingo',
  };

  @override
  Widget build(BuildContext context) {
    final claveHoy = _clavesPorWeekday[DateTime.now().weekday];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        const SizedBox(height: 24),
        const Text(
          'Horario de atención',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),
        for (final dia in diasSemana.entries)
          Builder(
            builder: (context) {
              final abierto = horario[dia.key] != null;
              final esHoy = dia.key == claveHoy;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: abierto
                            ? const Color(0xFF70C84D)
                            : const Color(0xFFC4C4C4),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        dia.value.toLowerCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              esHoy ? FontWeight.w700 : FontWeight.w400,
                          color: abierto
                              ? const Color(0xFF111827)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    Text(
                      formatearHorario(horario[dia.key]),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: esHoy ? FontWeight.w700 : FontWeight.w400,
                        color: abierto
                            ? const Color(0xFF111827)
                            : const Color(0xFF6B7280),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
      ],
    );
  }
}
