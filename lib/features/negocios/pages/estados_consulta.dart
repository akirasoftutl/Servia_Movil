part of 'perfil_negocio_page.dart';

// Se comparte solo dentro de negocios; reproduce los estados de AuthGate.
class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _PantallaErrorRed extends StatelessWidget {
  const _PantallaErrorRed({required this.error, this.onReintentar});

  final Object error;
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
          Text(
            MensajesNegocios.mensajeDeError(error),
            textAlign: TextAlign.center,
          ),
          if (onReintentar != null &&
              MensajesNegocios.puedeReintentar(error)) ...[
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
