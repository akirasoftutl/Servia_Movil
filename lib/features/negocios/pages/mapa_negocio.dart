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
      const Divider(height: 1, color: _divisor),
      const SizedBox(height: Espacios.xl),
      const Text(
        MensajesNegocios.ubicacion,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: _texto,
          letterSpacing: -0.3,
        ),
      ),
      const SizedBox(height: 14),
      Semantics(
        label: MensajesNegocios.descripcionMapa,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radio),
          child: Image(
            image: proveedor(
              '${ApiClient.baseUrl}/negocios/${Uri.encodeComponent(negocioId)}/mapa',
            ),
            excludeFromSemantics: true,
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            frameBuilder: (_, child, frame, sincrono) =>
                frame != null || sincrono
                ? child
                : const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, _, _) => const Text(MensajesNegocios.errorMapa),
          ),
        ),
      ),
      const SizedBox(height: Espacios.m),
      SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton.icon(
          onPressed: () => _comoLlegar(context),
          style: _estiloBotonPrincipal,
          icon: const Icon(Icons.directions_outlined),
          label: const Text(MensajesNegocios.comoLlegar),
        ),
      ),
    ],
  );
}

// Literales del rediseño (bloques del perfil y botón principal en píldora
// negra de `confirmacion_reserva_page.dart`), sin agregarlos al tema.
const _divisor = Color(0xFFE5E7EB);
const _texto = Color(0xFF111827);
const _radio = 16.0;

/// Botón principal en píldora negra como los del rediseño.
final _estiloBotonPrincipal = FilledButton.styleFrom(
  backgroundColor: const Color(0xFF0F0F0F),
  foregroundColor: Colors.white,
  shape: const StadiumBorder(),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);
