import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/etiqueta_estado.dart';
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
    final Widget contenido;
    switch (_estado) {
      case _EstadoPerfil.cargando:
        contenido = const EstadoCargando();
      case _EstadoPerfil.error:
        contenido = EstadoError(
          mensaje: MensajesNegocios.mensajeDeError(_error!),
          onReintentar: MensajesNegocios.puedeReintentar(_error!)
              ? _cargar
              : null,
        );
      case _EstadoPerfil.listo:
        contenido = _ContenidoPerfil(
          negocio: _negocio!,
          categoria: _categoria!,
          service: _service,
          proveedorFotos: widget.proveedorFotos,
        );
    }
    return Scaffold(
      appBar: AppBar(title: const Text(MensajesNegocios.tituloPerfil)),
      body: contenido,
    );
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Espacios.l,
        Espacios.s,
        Espacios.l,
        Espacios.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fotos.portada != null) ...[
            PortadaNegocio(
              foto: fotos.portada!,
              proveedor: proveedorFotos,
            ),
            const SizedBox(height: Espacios.l),
          ],
          if (fotos.galeria.isNotEmpty) ...[
            GaleriaFotosNegocio(
              fotos: fotos.galeria,
              proveedor: proveedorFotos,
            ),
            const SizedBox(height: Espacios.xl),
          ],
          _EncabezadoNegocio(negocio: negocio, categoria: categoria),
          const SizedBox(height: Espacios.xl),
          _ContactoNegocio(negocio: negocio),
          const SizedBox(height: Espacios.xl),
          _HorarioSemanal(horario: negocio.horario),
          const SizedBox(height: Espacios.xl),
          SeccionServicios(
            negocioId: negocio.id,
            negocioNombre: negocio.nombre,
            aceptaReservas: negocio.aceptaReservas,
            service: service,
          ),
        ],
      ),
    );
  }
}

class _EncabezadoNegocio extends StatelessWidget {
  const _EncabezadoNegocio({required this.negocio, required this.categoria});
  final Negocio negocio;
  final String categoria;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MiniaturaNegocio(nombre: negocio.nombre, tamano: 64),
            const SizedBox(width: Espacios.l),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(negocio.nombre, style: textos.headlineSmall),
                  const SizedBox(height: Espacios.xs),
                  Text(categoria, style: textos.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Espacios.l),
        EtiquetaEstado(
          texto: negocio.aceptaReservas
              ? MensajesNegocios.aceptaReservas
              : MensajesNegocios.noAceptaReservas,
          tono: negocio.aceptaReservas ? TonoEstado.exito : TonoEstado.neutro,
        ),
        if (negocio.descripcion != null) ...[
          const SizedBox(height: Espacios.l),
          Text(negocio.descripcion!, style: textos.bodyLarge),
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
    final filas = [
      if (negocio.direccionTexto != null)
        _FilaContacto(Icons.place_outlined, negocio.direccionTexto!),
      if (negocio.telefono != null)
        _FilaContacto(Icons.phone_outlined, negocio.telefono!),
      if (negocio.correoContacto != null)
        _FilaContacto(Icons.mail_outline, negocio.correoContacto!),
    ];
    if (filas.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Espacios.s),
        child: Column(children: filas),
      ),
    );
  }
}

class _FilaContacto extends StatelessWidget {
  const _FilaContacto(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.l,
        vertical: Espacios.s,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: tema.colorScheme.onSurfaceVariant),
          const SizedBox(width: Espacios.m),
          Expanded(child: Text(texto, style: tema.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _HorarioSemanal extends StatelessWidget {
  const _HorarioSemanal({required this.horario});
  final Map<String, HorarioDia?> horario;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final suave = tema.textTheme.bodyMedium?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(MensajesNegocios.horario, style: tema.textTheme.titleLarge),
        const SizedBox(height: Espacios.m),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Espacios.l,
              vertical: Espacios.s,
            ),
            child: Column(
              children: [
                for (final dia in diasSemana.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Espacios.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            dia.value,
                            style: tema.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          formatearHorario(horario[dia.key]),
                          style: horario[dia.key] == null
                              ? suave
                              : tema.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
