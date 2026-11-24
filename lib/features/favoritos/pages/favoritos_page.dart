import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../../negocios/data/categoria.dart';
import '../../negocios/data/negocios_service.dart';
import '../../negocios/pages/tarjeta_negocio.dart';
import '../../negocios/pages/detalle_servicio_page.dart';
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
      appBar: AppBar(
        title: const Text(MensajesFavoritos.titulo),
        bottom: TabBar(
          controller: _pestanas,
          tabs: const [
            Tab(text: MensajesFavoritos.tabNegocios),
            Tab(text: MensajesFavoritos.tabServicios),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
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
          padding: Espacios.pantalla.copyWith(bottom: Espacios.xl),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: Espacios.m),
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
          padding: Espacios.pantalla.copyWith(bottom: Espacios.xl),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: Espacios.m),
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
