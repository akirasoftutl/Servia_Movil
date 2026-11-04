import 'package:flutter/material.dart';

import '../theme/colores_servia.dart';
import '../theme/tokens.dart';

enum TipoAviso { error, advertencia, informacion }

/// Aviso en línea (error de un formulario, advertencia, información).
class Aviso extends StatelessWidget {
  const Aviso({
    super.key,
    required this.texto,
    this.tipo = TipoAviso.error,
    this.icono,
  });

  final String texto;
  final TipoAviso tipo;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = tema.colorScheme;
    final s = ColoresSemanticos.de(context);
    final (fondo, frente, iconoBase) = switch (tipo) {
      TipoAviso.error => (
        c.errorContainer,
        c.onErrorContainer,
        Icons.error_outline,
      ),
      TipoAviso.advertencia => (
        s.avisoFondo,
        s.aviso,
        Icons.warning_amber_outlined,
      ),
      TipoAviso.informacion => (
        c.primaryContainer,
        c.onPrimaryContainer,
        Icons.info_outline,
      ),
    };
    return Semantics(
      liveRegion: tipo == TipoAviso.error,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: Espacios.m + 2,
          vertical: Espacios.m,
        ),
        decoration: BoxDecoration(color: fondo, borderRadius: Radios.campo),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono ?? iconoBase, size: 20, color: frente),
            const SizedBox(width: Espacios.m),
            Expanded(
              child: Text(
                texto,
                style: tema.textTheme.bodyMedium?.copyWith(color: frente),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de un campo de formulario, encima del campo.
class EtiquetaCampo extends StatelessWidget {
  const EtiquetaCampo(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Espacios.s),
    child: Text(texto, style: Theme.of(context).textTheme.titleSmall),
  );
}
