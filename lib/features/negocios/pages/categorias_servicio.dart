import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../data/servicio.dart';
import '../mensajes.dart';

/// Categorías de catálogo que tienen los [servicios], sin repetir y en el
/// orden en que aparecen. Las personalizadas no cuentan (no son chips).
List<CategoriaServicio> categoriasDeCatalogo(List<Servicio> servicios) {
  final vistas = <String, CategoriaServicio>{};
  for (final servicio in servicios) {
    final categoria = servicio.categoriaServicio;
    if (categoria != null) vistas.putIfAbsent(categoria.id, () => categoria);
  }
  return vistas.values.toList();
}

/// Fila de chips «Todas» + una por categoría para filtrar los servicios del
/// negocio (Móvil#76). Usa el `chipTheme` del tema; sin categorías no se monta.
class FiltroCategoriasServicio extends StatelessWidget {
  const FiltroCategoriasServicio({
    super.key,
    required this.categorias,
    required this.categoriaId,
    required this.onCategoria,
  });

  final List<CategoriaServicio> categorias;

  /// Id elegido; `null` es «Todas».
  final String? categoriaId;
  final ValueChanged<String?> onCategoria;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: MensajesNegocios.filtrarPorCategoria,
      child: Wrap(
        spacing: Espacios.s,
        runSpacing: Espacios.xs,
        children: [
          ChoiceChip(
            label: const Text(MensajesNegocios.todas),
            selected: categoriaId == null,
            onSelected: (_) => onCategoria(null),
          ),
          for (final categoria in categorias)
            ChoiceChip(
              label: Text(categoria.nombre),
              selected: categoriaId == categoria.id,
              onSelected: (_) => onCategoria(categoria.id),
            ),
        ],
      ),
    );
  }
}

/// Texto de la categoría de un servicio, de catálogo o personalizada (se ven
/// igual). Sin categoría no ocupa nada.
class CategoriaDelServicio extends StatelessWidget {
  const CategoriaDelServicio({super.key, required this.servicio, this.estilo});

  final Servicio servicio;

  /// Por omisión `bodySmall` del tema.
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    final nombre = servicio.categoria;
    if (nombre == null) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final color = tema.colorScheme.onSurfaceVariant;
    return Semantics(
      label: MensajesNegocios.categoriaDelServicio(nombre),
      excludeSemantics: true,
      child: Text(
        nombre,
        style: (estilo ?? tema.textTheme.bodySmall)?.copyWith(color: color),
      ),
    );
  }
}
