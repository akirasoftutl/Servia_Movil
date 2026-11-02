import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        TextField(
          controller: texto,
          maxLength: 50,
          onChanged: onTexto,
          decoration: InputDecoration(
            labelText: MensajesNegocios.buscar,
            suffixIcon: IconButton(
              tooltip: MensajesNegocios.limpiar,
              icon: const Icon(Icons.clear),
              onPressed: onLimpiar,
            ),
          ),
        ),
        if (categorias.isNotEmpty)
          DropdownButton<String>(
            value: categoriaId ?? '',
            isExpanded: true,
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
      ],
    ),
  );
}
