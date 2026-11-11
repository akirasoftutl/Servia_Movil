import 'package:material_ui/material_ui.dart';

import '../theme/colores_servia.dart';
import '../theme/tokens.dart';

enum TonoEstado { exito, aviso, neutro }

/// Etiqueta corta de estado con color semántico (p. ej. «Acepta reservas»).
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado({
    super.key,
    required this.texto,
    this.tono = TonoEstado.neutro,
    this.icono,
  });

  final String texto;
  final TonoEstado tono;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final s = ColoresSemanticos.de(context);
    final (frente, fondo) = switch (tono) {
      TonoEstado.exito => (s.exito, s.exitoFondo),
      TonoEstado.aviso => (s.aviso, s.avisoFondo),
      TonoEstado.neutro => (s.neutro, s.neutroFondo),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Espacios.s,
        vertical: Espacios.xs,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono ?? _iconoDe(tono), size: 14, color: frente),
          const SizedBox(width: Espacios.xs),
          Flexible(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: frente),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconoDe(TonoEstado tono) => switch (tono) {
    TonoEstado.exito => Icons.check_circle_outline,
    TonoEstado.aviso => Icons.schedule,
    TonoEstado.neutro => Icons.remove_circle_outline,
  };
}
