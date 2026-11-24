import 'package:flutter/material.dart';

import '../../negocios/data/negocio.dart';
import '../../negocios/data/negocio_resumen.dart';
import '../data/favoritos_controlador.dart';
import '../mensajes.dart';

/// Resumen del negocio del perfil para guardarlo en la lista al instante.
NegocioResumen resumenDeNegocio(Negocio negocio) => NegocioResumen(
  id: negocio.id,
  nombre: negocio.nombre,
  categoriaId: negocio.categoriaId,
  aceptaReservas: negocio.aceptaReservas,
  imagenUrl: negocio.fotos.portada?.url,
);

/// Corazón para agregar o quitar un negocio de favoritos (HU-C81, HU-C83).
///
/// Cambia al instante y vuelve a su estado si la API falla, avisando con un
/// SnackBar del tema. Sin sesión no se muestra. [sobreFoto] le da el fondo
/// de superficie que usan los botones sobre la portada.
class BotonFavorito extends StatelessWidget {
  const BotonFavorito({
    super.key,
    required this.negocio,
    this.controlador,
    this.sobreFoto = false,
  });

  final NegocioResumen negocio;
  final FavoritosControlador? controlador;
  final bool sobreFoto;

  Future<void> _pulsar(
    BuildContext context,
    FavoritosControlador favoritos,
  ) async {
    // Se toma antes de esperar: en la lista el botón desaparece al quitarlo.
    final mensajero = ScaffoldMessenger.of(context);
    try {
      if (favoritos.estado == EstadoFavoritos.error) {
        await favoritos.cargar();
        if (favoritos.estado == EstadoFavoritos.error) {
          throw favoritos.error!;
        }
        return;
      }
      await favoritos.alternar(negocio);
    } catch (error) {
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(MensajesFavoritos.mensajeDeCambio(error))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritos = controlador ?? FavoritosControlador.instancia;
    final c = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: favoritos,
      builder: (context, _) {
        if (!favoritos.haySesion) return const SizedBox.shrink();
        final estado = favoritos.estado;
        final conError = estado == EstadoFavoritos.error;
        final esFavorito = favoritos.esFavorito(negocio.id);
        final ocupado =
            estado == EstadoFavoritos.inicial ||
            estado == EstadoFavoritos.cargando ||
            favoritos.estaGuardando(negocio.id);
        return IconButton(
          tooltip: conError
              ? MensajesFavoritos.reintentarEstado
              : esFavorito
              ? MensajesFavoritos.quitar
              : MensajesFavoritos.agregar,
          isSelected: esFavorito,
          icon: const Icon(Icons.favorite_border),
          selectedIcon: const Icon(Icons.favorite),
          style: IconButton.styleFrom(
            foregroundColor: esFavorito ? c.primary : c.onSurfaceVariant,
            backgroundColor: sobreFoto
                ? c.surface.withValues(alpha: 0.92)
                : null,
          ),
          onPressed: ocupado ? null : () => _pulsar(context, favoritos),
        );
      },
    );
  }
}
