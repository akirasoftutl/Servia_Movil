import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../../negocios/data/categoria.dart';
import '../../negocios/data/negocios_service.dart';
import '../../negocios/pages/tarjeta_negocio.dart';
import '../data/favoritos_controlador.dart';
import '../mensajes.dart';
import 'boton_favorito.dart';

/// «Mis favoritos»: los negocios guardados por el cliente, del más reciente
/// al más antiguo (HU-C82, HU-C83).
class FavoritosPage extends StatefulWidget {
  const FavoritosPage({super.key, this.controlador, this.negociosService});

  final FavoritosControlador? controlador;
  final NegociosService? negociosService;

  @override
  State<FavoritosPage> createState() => _FavoritosPageState();
}

class _FavoritosPageState extends State<FavoritosPage> {
  late final FavoritosControlador _favoritos;
  late final NegociosService _negocios;
  List<Categoria> _categorias = const [];

  @override
  void initState() {
    super.initState();
    _favoritos = widget.controlador ?? FavoritosControlador.instancia;
    _negocios = widget.negociosService ?? NegociosService();
    _favoritos.cargar();
    _cargarCategorias();
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
      appBar: AppBar(title: const Text(MensajesFavoritos.titulo)),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(listenable: _favoritos, builder: _cuerpo),
      ),
    );
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
