import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../../negocios/data/categoria.dart';
import '../../negocios/data/negocios_service.dart';
import '../../negocios/pages/detalle_servicio_page.dart';
import '../../negocios/pages/tarjeta_negocio.dart';
import '../data/favoritos_controlador.dart';
import '../data/favoritos_servicios_controlador.dart';
import '../data/servicio_favorito.dart';
import '../mensajes.dart';
import 'boton_favorito.dart';
import 'boton_favorito_servicio.dart';
import 'tarjeta_servicio_favorito.dart';

/// «Mis favoritos»: dos pestañas, «Negocios» (HU-C82, HU-C83) y «Servicios»
/// (HU-C84), cada una del más reciente al más antiguo.
class FavoritosPage extends StatefulWidget {
  const FavoritosPage({
    super.key,
    this.controlador,
    this.serviciosControlador,
    this.negociosService,
  });

  final FavoritosControlador? controlador;
  final FavoritosServiciosControlador? serviciosControlador;
  final NegociosService? negociosService;

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage>
    with SingleTickerProviderStateMixin {
  late final FavoritosControlador _favoritos;
  late final FavoritosServiciosControlador _servicios;
  late final TabController _pestanas;
  late final NegociosService _negocios;
  List<Categoria> _categorias = const [];
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _favoritos = widget.controlador ?? FavoritosControlador.instancia;
    _servicios =
        widget.serviciosControlador ?? FavoritosServiciosControlador.instancia;
    _negocios = widget.negociosService ?? NegociosService();
    _pestanas = TabController(length: 2, vsync: this)
      ..addListener(_alCambiarPestana);
    _favoritos.cargar();
    _cargarCategorias();
  }

  @override
  void dispose() {
    _pestanas
      ..removeListener(_alCambiarPestana)
      ..dispose();
    super.dispose();
  }

  /// Los servicios se consultan al abrir su pestaña (y se refrescan al volver).
  void _alCambiarPestana() {
    if (_pestanas.index != _indice) {
      setState(() => _indice = _pestanas.index);
    }
    if (!_pestanas.indexIsChanging && _pestanas.index == 1) {
      _servicios.cargar();
    }
  }

  void _abrirServicio(ServicioFavorito servicio) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DetalleServicioPage(
          negocioId: servicio.negocioId,
          servicioId: servicio.servicioId,
          aceptaReservas: servicio.aceptaReservas,
          negocioNombre: servicio.negocioNombre,
          negociosService: widget.negociosService,
          favoritos: _servicios,
        ),
      ),
    );
  }

  /// El catálogo solo pone el nombre de la categoría: si falla, la tarjeta
  /// sale sin ella (como el perfil del negocio).
  Future<void> _cargarCategorias() async {
    try {
      final categorias = await _negocios.obtenerCategorias();
      if (!mounted) return;
      setState(() => _categorias = categorias);
    } catch (_) {
      // Sin catálogo no se impide ver los favoritos.
    }
  }

  String _nombreCategoria(String? id) {
    for (final categoria in _categorias) {
      if (categoria.id == id) return categoria.nombre;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado limpio estilo Fresha con flecha para regresar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 20, 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF111827),
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      MensajesFavoritos.titulo,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Selector de pestañas tipo píldora ("Negocios" / "Servicios")
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              // A 2x las píldoras no caben juntas: la segunda baja de línea.
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _ChipPestanaFavoritos(
                    texto: MensajesFavoritos.tabNegocios,
                    seleccionada: _indice == 0,
                    onTap: () => _pestanas.animateTo(0),
                  ),
                  _ChipPestanaFavoritos(
                    texto: MensajesFavoritos.tabServicios,
                    seleccionada: _indice == 1,
                    onTap: () => _pestanas.animateTo(1),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            Expanded(
              child: TabBarView(
                controller: _pestanas,
                children: [
                  ListenableBuilder(listenable: _favoritos, builder: _cuerpo),
                  ListenableBuilder(
                    listenable: _servicios,
                    builder: _cuerpoServicios,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cuerpoServicios(BuildContext context, Widget? _) {
    switch (_servicios.estado) {
      case EstadoFavoritos.inicial:
      case EstadoFavoritos.cargando:
        return const EstadoCargando(mensaje: MensajesFavoritos.cargando);
      case EstadoFavoritos.error:
        final error = _servicios.error!;
        return EstadoError(
          mensaje: MensajesFavoritos.mensajeDeCarga(error),
          onReintentar: MensajesFavoritos.puedeReintentarCarga(error)
              ? _servicios.cargar
              : null,
        );
      case EstadoFavoritos.listo:
        final items = _servicios.items;
        if (items.isEmpty) {
          return const EstadoVacio(
            icono: Icons.favorite_border,
            mensaje: MensajesFavoritos.sinServicios,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, Espacios.xl),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, indice) {
            final servicio = items[indice];
            return TarjetaServicioFavorito(
              key: ValueKey(servicio.clave),
              servicio: servicio,
              onAbrir: () => _abrirServicio(servicio),
              accion: BotonFavoritoServicio(
                servicio: servicio,
                controlador: _servicios,
              ),
            );
          },
        );
    }
  }

  Widget _cuerpo(BuildContext context, Widget? _) {
    switch (_favoritos.estado) {
      case EstadoFavoritos.inicial:
      case EstadoFavoritos.cargando:
        return const EstadoCargando(mensaje: MensajesFavoritos.cargando);
      case EstadoFavoritos.error:
        final error = _favoritos.error!;
        return EstadoError(
          mensaje: MensajesFavoritos.mensajeDeCarga(error),
          onReintentar: MensajesFavoritos.puedeReintentarCarga(error)
              ? _favoritos.cargar
              : null,
        );
      case EstadoFavoritos.listo:
        final items = _favoritos.items;
        if (items.isEmpty) {
          return const EstadoVacio(
            icono: Icons.favorite_border,
            mensaje: MensajesFavoritos.sinFavoritos,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, Espacios.xl),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (context, indice) {
            final negocio = items[indice];
            return TarjetaNegocio(
              key: ValueKey(negocio.id),
              negocio: negocio,
              categoria: _nombreCategoria(negocio.categoriaId),
              accion: BotonFavorito(negocio: negocio, controlador: _favoritos),
            );
          },
        );
    }
  }
}

class _ChipPestanaFavoritos extends StatelessWidget {
  const _ChipPestanaFavoritos({
    required this.texto,
    required this.seleccionada,
    required this.onTap,
  });

  final String texto;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // El área táctil mide 48 dp aunque la píldora visible sea más baja.
    return SizedBox(
      height: Medidas.tactil,
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: seleccionada ? const Color(0xFF0F0F0F) : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: seleccionada
                    ? const Color(0xFF0F0F0F)
                    : const Color(0xFFD1D5DB),
                width: 1,
              ),
            ),
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: seleccionada ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
