import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../data/favoritos_controlador.dart';
import '../data/favoritos_servicios_controlador.dart';
import '../data/servicio_favorito.dart';
import '../mensajes.dart';

/// Corazón para agregar o quitar un servicio de favoritos (HU-C84).
///
/// Cambia al instante y vuelve a su estado si la API falla, avisando con un
/// SnackBar del tema (404: servicio no disponible; 409: tope de 100). Sin
/// sesión no se muestra. Mismo comportamiento que `BotonFavorito` (negocios).
class BotonFavoritoServicio extends StatelessWidget {
  const BotonFavoritoServicio({
    super.key,
    required this.servicio,
    this.controlador,
  });

  final ServicioFavorito servicio;
  final FavoritosServiciosControlador? controlador;

  Future<void> _pulsar(
    BuildContext context,
    FavoritosServiciosControlador favoritos,
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
      await favoritos.alternar(servicio);
    } catch (error) {
      mensajero
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              MensajesFavoritos.mensajeDeCambio(error, servicio: true),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final favoritos = controlador ?? FavoritosServiciosControlador.instancia;
    final c = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: favoritos,
      builder: (context, _) {
        if (!favoritos.haySesion) return const SizedBox.shrink();
        final estado = favoritos.estado;
        final conError = estado == EstadoFavoritos.error;
        final esFavorito = favoritos.esFavorito(
          servicio.negocioId,
          servicio.servicioId,
        );
        final ocupado =
            estado == EstadoFavoritos.inicial ||
            estado == EstadoFavoritos.cargando ||
            favoritos.estaGuardando(servicio.negocioId, servicio.servicioId);
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
            minimumSize: const Size.square(Medidas.tactil),
            foregroundColor: esFavorito ? c.primary : c.onSurfaceVariant,
          ),
          onPressed: ocupado ? null : () => _pulsar(context, favoritos),
        );
      },
    );
  }
}
