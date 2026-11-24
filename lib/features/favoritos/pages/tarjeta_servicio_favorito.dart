import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../negocios/formatos.dart';
import '../data/servicio_favorito.dart';

/// Fila de un servicio favorito en «Mis favoritos» > «Servicios»: nombre,
/// negocio, precio y duración (HU-C84). Tocarla abre el detalle del servicio;
/// [accion] va a la derecha (el corazón para quitarlo).
class TarjetaServicioFavorito extends StatelessWidget {
  const TarjetaServicioFavorito({
    super.key,
    required this.servicio,
    required this.onAbrir,
    this.accion,
  });

  final ServicioFavorito servicio;
  final VoidCallback onAbrir;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = tema.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: Radios.tarjeta,
        onTap: onAbrir,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Radios.tarjeta,
            border: Border.all(color: c.outlineVariant),
          ),
          padding: const EdgeInsets.only(
            left: Espacios.l,
            top: Espacios.s,
            bottom: Espacios.s,
            right: Espacios.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Espacios.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(servicio.nombre, style: tema.textTheme.titleSmall),
                      const SizedBox(height: Espacios.xs),
                      Text(
                        servicio.negocioNombre,
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Espacios.s),
                      Wrap(
                        spacing: Espacios.m,
                        children: [
                          Text(
                            formatearPrecio(servicio.precio),
                            style: tema.textTheme.titleSmall,
                          ),
                          Text(
                            formatearDuracion(servicio.duracionMin),
                            style: tema.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ?accion,
            ],
          ),
        ),
      ),
    );
  }
}
