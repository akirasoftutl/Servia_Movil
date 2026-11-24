import 'package:flutter/material.dart';

import '../data/negocio_resumen.dart';
import '../data/negocios_service.dart';
import '../mensajes.dart';

// Mismos valores literales que las tarjetas de la lista del rediseño
// (`lista_negocios_page.dart`), sin agregarlos al tema.
const _borde = Color(0xFFE5E7EB);
const _texto = Color(0xFF111827);
const _textoSecundario = Color(0xFF6B7280);
const _marcador = Color(0xFFF3F4F6);
const _iconoMarcador = Color(0xFF9CA3AF);
const _exito = Color(0xFF15803D);
const _radio = 16.0;
const _portada = 108.0;

/// Tarjeta de «Cerca de ti»: portada a la izquierda como la tarjeta
/// horizontal de la lista, con la distancia en lugar de la categoría.
class TarjetaNegocio extends StatelessWidget {
  const TarjetaNegocio({
    super.key,
    required this.negocio,
    required this.categoria,
    this.onTap,
  });
  final NegocioResumen negocio;

  /// Sin categoría (la API la declara `string | null`) no se muestra la línea.
  final String? categoria;

  /// Por omisión abre `/negocios/{id}`; la portada de inicio abre el perfil
  /// con el servicio que ya tiene.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = negocio.imagenUrl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_radio),
        onTap:
            onTap ??
            () {
              if (esIdValido(negocio.id)) {
                Navigator.pushNamed(context, '/negocios/${negocio.id}');
              }
            },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_radio),
            border: Border.all(color: _borde),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _portada),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(_radio - 1),
                    ),
                    child: SizedBox(
                      width: _portada,
                      child: _Portada(
                        url: url != null && url.isNotEmpty ? url : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            negocio.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _texto,
                            ),
                          ),
                          if (categoria case final categoria?) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 15,
                                  color: _textoSecundario,
                                ),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    categoria,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: _textoSecundario,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            negocio.aceptaReservas
                                ? MensajesNegocios.aceptaReservas
                                : MensajesNegocios.noAceptaReservas,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: negocio.aceptaReservas
                                  ? _exito
                                  : _textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Portada del negocio; sin URL (o si falla la carga) muestra el mismo
/// marcador gris que la lista.
class _Portada extends StatelessWidget {
  const _Portada({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final marcador = Container(
      color: _marcador,
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_outlined,
        size: 24,
        color: _iconoMarcador,
      ),
    );
    if (url == null) return marcador;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => marcador,
    );
  }
}
