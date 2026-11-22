import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/tokens.dart';
import '../data/ubicacion_negocio.dart';
import '../mensajes.dart';
import 'fotos_negocio.dart';

typedef LanzadorRutaNegocio = Future<bool> Function(Uri uri);

Future<bool> abrirRutaNegocio(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class MapaNegocio extends StatelessWidget {
  const MapaNegocio({
    super.key,
    required this.negocioId,
    required this.ubicacion,
    this.proveedor = NetworkImage.new,
    this.lanzador = abrirRutaNegocio,
  });

  final String negocioId;
  final UbicacionNegocio ubicacion;
  final ProveedorImagenNegocio proveedor;
  final LanzadorRutaNegocio lanzador;

  Future<void> _comoLlegar(BuildContext context) async {
    final ruta = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${ubicacion.lat},${ubicacion.lng}',
    );
    var abierto = false;
    try {
      abierto = await lanzador(ruta);
    } catch (_) {
      abierto = false;
    }
    if (!context.mounted || abierto) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(MensajesNegocios.errorAppMapas)),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        MensajesNegocios.ubicacion,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: Espacios.m),
      Semantics(
        label: MensajesNegocios.descripcionMapa,
        child: Image(
          image: proveedor(
            '${ApiClient.baseUrl}/negocios/${Uri.encodeComponent(negocioId)}/mapa',
          ),
          excludeFromSemantics: true,
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          frameBuilder: (_, child, frame, sincrono) => frame != null || sincrono
              ? child
              : const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (_, _, _) => const Text(MensajesNegocios.errorMapa),
        ),
      ),
      const SizedBox(height: Espacios.s),
      FilledButton.icon(
        onPressed: () => _comoLlegar(context),
        icon: const Icon(Icons.directions_outlined),
        label: const Text(MensajesNegocios.comoLlegar),
      ),
    ],
  );
}
