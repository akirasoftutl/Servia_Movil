import 'package:material_ui/material_ui.dart';

import '../../../core/theme/colores_servia.dart';
import '../../../core/theme/tokens.dart';

/// Marcador de la imagen de un negocio (la API aún no expone fotos): la
/// inicial del nombre sobre el tono de marca.
class MiniaturaNegocio extends StatelessWidget {
  const MiniaturaNegocio({
    super.key,
    required this.nombre,
    this.tamano = Medidas.miniatura,
  });

  final String nombre;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final inicial = nombre.trim().isEmpty
        ? '·'
        : nombre.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.primaryContainer,
          borderRadius: BorderRadius.circular(tamano * 0.25),
        ),
        child: Text(
          inicial,
          // La inicial es decorativa y su pieza tiene tamaño fijo.
          textScaler: TextScaler.noScaling,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(height: 1, color: ColoresServia.primario),
        ),
      ),
    );
  }
}
