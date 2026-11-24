import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../data/orden_negocios.dart';
import '../mensajes.dart';

/// Lista desplegable «Ordenar por» con el estilo del selector de categoría.
/// Cerrada muestra «Ordenar por: Nombre (A-Z)»; el menú, solo las dos opciones.
/// Mide al menos 48 dp y se ajusta con la escala de texto del sistema.
class SelectorOrdenNegocios extends StatelessWidget {
  const SelectorOrdenNegocios({
    super.key,
    required this.orden,
    required this.onOrden,
  });

  final OrdenNegocios orden;
  final ValueChanged<OrdenNegocios> onOrden;

  /// Tope de ancho: en pantallas angostas ocupa toda la línea.
  static const anchoMaximo = Medidas.logo * 4;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final estilo = Theme.of(context).textTheme.bodyLarge;
    return Semantics(
      label: MensajesNegocios.ordenarPor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: anchoMaximo),
        child: Container(
          constraints: const BoxConstraints(minHeight: Medidas.tactil),
          padding: const EdgeInsets.only(left: Espacios.m, right: Espacios.xs),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: Radios.campo,
            border: Border.all(color: c.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<OrdenNegocios>(
              value: orden,
              isExpanded: true,
              borderRadius: Radios.campo,
              style: estilo,
              icon: const Icon(Icons.expand_more),
              selectedItemBuilder: (_) => [
                for (final opcion in OrdenNegocios.values)
                  Row(
                    children: [
                      Icon(
                        Icons.swap_vert,
                        size: Espacios.xl,
                        color: c.onSurfaceVariant,
                      ),
                      const SizedBox(width: Espacios.s),
                      Expanded(
                        child: Text(
                          MensajesNegocios.ordenarPorOpcion(opcion.etiqueta),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
              items: [
                for (final opcion in OrdenNegocios.values)
                  DropdownMenuItem(value: opcion, child: Text(opcion.etiqueta)),
              ],
              onChanged: (elegido) {
                if (elegido != null) onOrden(elegido);
              },
            ),
          ),
        ),
      ),
    );
  }
}
