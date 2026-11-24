import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// Botones del rediseño (píldora) armados con el esquema del tema, para que
/// «Mi perfil» y sus diálogos se vean como el resto de la app sin repetir
/// colores ni medidas.

/// Acción principal: píldora de tinta oscura. Si [destructiva], con el color
/// de error (borrar la cuenta).
ButtonStyle estiloPildoraPrincipal(
  BuildContext context, {
  bool destructiva = false,
}) {
  final c = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: destructiva ? c.error : c.onSurface,
    foregroundColor: destructiva ? c.onError : c.surface,
    minimumSize: const Size(Medidas.boton, Medidas.boton),
    shape: const StadiumBorder(),
  );
}

/// Acción secundaria: píldora con borde.
ButtonStyle estiloPildoraSecundaria(BuildContext context) {
  final c = Theme.of(context).colorScheme;
  return OutlinedButton.styleFrom(
    foregroundColor: c.onSurface,
    side: BorderSide(color: c.outline),
    minimumSize: const Size(Medidas.tactil, Medidas.tactil),
    shape: const StadiumBorder(),
  );
}

/// Acción de texto que quita algo (por ejemplo, la foto).
ButtonStyle estiloAccionQuitar(BuildContext context) =>
    TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error);
