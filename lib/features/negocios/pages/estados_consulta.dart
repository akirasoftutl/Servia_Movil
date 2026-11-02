import 'package:flutter/material.dart';

import '../mensajes.dart';

// Se comparte solo dentro de negocios; reproduce los estados de AuthGate.
class CargaNegocio extends StatelessWidget {
  const CargaNegocio({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class ErrorNegocio extends StatelessWidget {
  const ErrorNegocio({super.key, required this.mensaje, this.onReintentar});

  final String mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(mensaje, textAlign: TextAlign.center),
          if (onReintentar != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onReintentar,
              child: const Text(MensajesNegocios.reintentar),
            ),
          ],
        ],
      ),
    ),
  );
}
