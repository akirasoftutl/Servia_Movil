import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../mensajes.dart';
import 'estilos_perfil.dart';

/// Diálogo de confirmación con los botones del rediseño (el de cancelar una
/// reserva): «Cancelar» secundario y la acción en píldora. Fondo y forma salen
/// del `dialogTheme`. Devuelve `true` solo si se confirma.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required List<String> parrafos,
  required String textoConfirmar,
  String textoCancelar = MensajesPerfil.cancelar,
  bool destructiva = false,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: Text(titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < parrafos.length; i++) ...[
              if (i > 0) const SizedBox(height: Espacios.m),
              Text(parrafos[i]),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(contexto, false),
          style: estiloPildoraSecundaria(contexto),
          child: Text(textoCancelar),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(contexto, true),
          style: estiloPildoraPrincipal(contexto, destructiva: destructiva),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}
