import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../data/categoria.dart';
import '../mensajes.dart';

class FiltrosNegocios extends StatelessWidget {
  const FiltrosNegocios({
    super.key,
    required this.texto,
    required this.categorias,
    required this.categoriaId,
    required this.onTexto,
    required this.onLimpiar,
    required this.onCategoria,
  });
  final TextEditingController texto;
  final List<Categoria> categorias;
  final String? categoriaId;
  final ValueChanged<String> onTexto;
  final VoidCallback onLimpiar;
  final ValueChanged<String?> onCategoria;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Espacios.l,
        Espacios.s,
        Espacios.l,
        Espacios.s,
      ),
      child: Column(
        children: [
          TextField(
            controller: texto,
            maxLength: 50,
            onChanged: onTexto,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: MensajesNegocios.buscar,
              floatingLabelBehavior: FloatingLabelBehavior.never,
              // El límite de 50 sigue activo; solo se oculta el contador.
              counterText: '',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: MensajesNegocios.limpiar,
                icon: const Icon(Icons.clear),
                onPressed: onLimpiar,
              ),
            ),
          ),
          if (categorias.isNotEmpty) ...[
            const SizedBox(height: Espacios.s),
            Container(
              padding: const EdgeInsets.only(
                left: Espacios.l,
                right: Espacios.s,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: Radios.campo,
                border: Border.all(color: c.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 20, color: c.onSurfaceVariant),
                  const SizedBox(width: Espacios.m),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: categoriaId ?? '',
                        isExpanded: true,
                        borderRadius: Radios.campo,
                        style: Theme.of(context).textTheme.bodyLarge,
                        icon: const Icon(Icons.expand_more),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text(MensajesNegocios.todas),
                          ),
                          for (final categoria in categorias)
                            DropdownMenuItem(
                              value: categoria.id,
                              child: Text(categoria.nombre),
                            ),
                        ],
                        onChanged: (id) => onCategoria(id == '' ? null : id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
