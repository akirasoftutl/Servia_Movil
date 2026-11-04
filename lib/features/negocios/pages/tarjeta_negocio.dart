import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/etiqueta_estado.dart';
import '../data/negocio_resumen.dart';
import '../data/negocios_service.dart';
import '../mensajes.dart';
import 'miniatura_negocio.dart';

class TarjetaNegocio extends StatelessWidget {
  const TarjetaNegocio({
    super.key,
    required this.negocio,
    required this.categoria,
  });
  final NegocioResumen negocio;
  final String categoria;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.l,
        vertical: Espacios.xs,
      ),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(
            Espacios.m,
            Espacios.xs,
            Espacios.s,
            Espacios.xs,
          ),
          leading: MiniaturaNegocio(nombre: negocio.nombre),
          title: Text(
            negocio.nombre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: Espacios.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(categoria, style: tema.textTheme.bodySmall),
                const SizedBox(height: Espacios.s),
                EtiquetaEstado(
                  texto: negocio.aceptaReservas
                      ? MensajesNegocios.aceptaReservas
                      : MensajesNegocios.noAceptaReservas,
                  tono: negocio.aceptaReservas
                      ? TonoEstado.exito
                      : TonoEstado.neutro,
                ),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (esIdValido(negocio.id)) {
              Navigator.pushNamed(context, '/negocios/${negocio.id}');
            }
          },
        ),
      ),
    );
  }
}
