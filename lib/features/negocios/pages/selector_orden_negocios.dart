import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../data/orden_negocios.dart';
import '../mensajes.dart';

/// Selector «Ordenar por» con forma de píldora, como los chips y botones del
/// rediseño de la app: colores y tipografía del tema, sin estilos propios.
/// Cerrado muestra «Ordenar por: Nombre (A-Z)»; el menú, solo las dos opciones.
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
    final tema = Theme.of(context);
    final c = tema.colorScheme;
    final estilo = tema.textTheme.labelMedium;
    final radioPildora = BorderRadius.circular(Medidas.tactil / 2);
    return Semantics(
      label: MensajesNegocios.ordenarPor,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: anchoMaximo),
        child: Container(
          constraints: const BoxConstraints(minHeight: Medidas.tactil),
          padding: const EdgeInsets.symmetric(
            horizontal: Espacios.m,
            vertical: Espacios.xs,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: radioPildora,
            border: Border.all(color: c.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<OrdenNegocios>(
              value: orden,
              isExpanded: true,
              borderRadius: Radios.tarjeta,
              style: estilo,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: c.onSurfaceVariant,
              ),
              selectedItemBuilder: (_) => [
                for (final opcion in OrdenNegocios.values)
                  Row(
                    children: [
                      Icon(
                        Icons.swap_vert_rounded,
                        size: Espacios.l + 2,
                        color: c.primary,
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
                  DropdownMenuItem<OrdenNegocios>(
                    value: opcion,
                    child: Row(
                      children: [
                        Icon(
                          opcion == orden
                              ? Icons.check_rounded
                              : Icons.swap_vert_rounded,
                          size: Espacios.l + 2,
                          color: opcion == orden
                              ? c.primary
                              : c.onSurfaceVariant,
                        ),
                        const SizedBox(width: Espacios.s),
                        Expanded(child: Text(opcion.etiqueta)),
                      ],
                    ),
                  ),
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
