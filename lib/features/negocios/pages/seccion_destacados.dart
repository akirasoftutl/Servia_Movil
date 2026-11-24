import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../data/negocio_resumen.dart';
import '../mensajes.dart';
import 'tarjeta_negocio.dart';

/// «Destacados» del inicio (HU-C26): título y una fila horizontal con una
/// [TarjetaNegocio] por negocio, en el orden en que los entrega la API.
/// Los estilos salen del tema y de los tokens de `core/theme`.
class SeccionDestacados extends StatelessWidget {
  const SeccionDestacados({
    super.key,
    required this.negocios,
    required this.nombreCategoria,
    required this.onAbrir,
  });

  final List<NegocioResumen> negocios;
  final String? Function(String? categoriaId) nombreCategoria;
  final ValueChanged<NegocioResumen> onAbrir;

  @override
  Widget build(BuildContext context) {
    // La siguiente tarjeta asoma para mostrar que la fila se desplaza.
    final ancho = (MediaQuery.sizeOf(context).width - 2 * Espacios.l) * 0.85;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espacios.l),
          child: Semantics(
            header: true,
            child: Text(
              MensajesNegocios.destacados,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        const SizedBox(height: Espacios.m),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Espacios.l),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < negocios.length; i++) ...[
                if (i > 0) const SizedBox(width: Espacios.m),
                SizedBox(
                  width: ancho,
                  child: TarjetaNegocio(
                    negocio: negocios[i],
                    categoria: nombreCategoria(negocios[i].categoriaId),
                    onTap: () => onAbrir(negocios[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
