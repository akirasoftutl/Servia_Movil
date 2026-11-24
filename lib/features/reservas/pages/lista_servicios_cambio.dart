import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../negocios/data/servicio.dart';
import '../../negocios/formatos.dart';

/// Servicios activos del negocio para cambiar el de la reserva (HU-C73).
class ListaServiciosCambio extends StatelessWidget {
  const ListaServiciosCambio({
    super.key,
    required this.servicios,
    required this.servicioIdActual,
    required this.onElegir,
  });

  final List<Servicio> servicios;
  final String servicioIdActual;
  final ValueChanged<Servicio> onElegir;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final servicio in servicios)
          ListTile(
            key: ValueKey('servicio-${servicio.id}'),
            minTileHeight: Medidas.tactil,
            title: Text(servicio.nombre),
            subtitle: Text(
              '${formatearDuracion(servicio.duracionMin)} · '
              '${formatearPrecio(servicio.precio)}',
            ),
            selected: servicio.id == servicioIdActual,
            selectedColor: c.primary,
            trailing: servicio.id == servicioIdActual
                ? const Icon(Icons.check_circle_outline)
                : null,
            onTap: () => onElegir(servicio),
          ),
      ],
    );
  }
}
