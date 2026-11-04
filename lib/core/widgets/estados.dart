import 'package:flutter/material.dart';

import '../theme/colores_servia.dart';
import '../theme/tokens.dart';

/// Estados comunes de consulta: cargando, vacío y error con «Reintentar».
/// Todas las pantallas los usan para que se vean igual. La variante
/// [compacto] es para una sección dentro de una pantalla (servicios, horas).

const _anchoTexto = 340.0;

/// Centra el estado en el espacio disponible; si el texto crece (tamaño de
/// letra del sistema) y no cabe, se desplaza en lugar de desbordarse.
class _Centrado extends StatelessWidget {
  const _Centrado({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      if (!limites.hasBoundedHeight) return Center(child: child);
      return SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: limites.maxHeight),
          child: Center(child: child),
        ),
      );
    },
  );
}

class EstadoCargando extends StatelessWidget {
  const EstadoCargando({super.key, this.mensaje, this.compacto = false});

  final String? mensaje;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final lado = compacto ? 28.0 : 36.0;
    return _Centrado(
      child: Padding(
        padding: EdgeInsets.all(compacto ? Espacios.l : Espacios.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: lado,
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
              ),
            ),
            if (mensaje != null) ...[
              const SizedBox(height: Espacios.l),
              Text(
                mensaje!,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.mensaje,
    this.detalle,
    this.accion,
    this.compacto = false,
  });

  final IconData icono;
  final String mensaje;
  final String? detalle;
  final Widget? accion;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return _Estado(
      compacto: compacto,
      icono: icono,
      colorIcono: ColoresServia.marca,
      fondoIcono: c.primaryContainer,
      mensaje: mensaje,
      detalle: detalle,
      accion: accion,
    );
  }
}

class EstadoError extends StatelessWidget {
  const EstadoError({
    super.key,
    required this.mensaje,
    this.onReintentar,
    this.textoReintentar = 'Reintentar',
    this.icono = Icons.cloud_off,
    this.compacto = false,
  });

  final String mensaje;

  /// Sin callback no se ofrece reintentar (por ejemplo, un 404).
  final VoidCallback? onReintentar;
  final String textoReintentar;
  final IconData icono;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    Widget? accion;
    if (onReintentar != null) {
      accion = compacto
          ? OutlinedButton(
              onPressed: onReintentar,
              child: Text(textoReintentar),
            )
          : ElevatedButton(
              onPressed: onReintentar,
              child: Text(textoReintentar),
            );
    }
    return _Estado(
      compacto: compacto,
      icono: icono,
      colorIcono: c.onSurfaceVariant,
      fondoIcono: c.surfaceContainerHigh,
      mensaje: mensaje,
      accion: accion,
      anunciar: true,
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado({
    required this.compacto,
    required this.icono,
    required this.colorIcono,
    required this.fondoIcono,
    required this.mensaje,
    this.detalle,
    this.accion,
    this.anunciar = false,
  });

  final bool compacto;
  final IconData icono;
  final Color colorIcono;
  final Color fondoIcono;
  final String mensaje;
  final String? detalle;
  final Widget? accion;
  final bool anunciar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final lado = compacto ? 44.0 : 72.0;
    return _Centrado(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Espacios.xl,
          vertical: compacto ? Espacios.l : Espacios.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _anchoTexto),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: lado,
                  height: lado,
                  decoration: BoxDecoration(
                    color: fondoIcono,
                    borderRadius: BorderRadius.circular(
                      compacto ? Radios.m : Radios.l + 4,
                    ),
                  ),
                  child: Icon(
                    icono,
                    size: compacto ? 24 : 34,
                    color: colorIcono,
                  ),
                ),
              ),
              SizedBox(height: compacto ? Espacios.m : Espacios.l),
              Semantics(
                liveRegion: anunciar,
                child: Text(
                  mensaje,
                  textAlign: TextAlign.center,
                  style: compacto
                      ? tema.textTheme.bodyMedium
                      : tema.textTheme.titleMedium,
                ),
              ),
              if (detalle != null) ...[
                const SizedBox(height: Espacios.xs),
                Text(
                  detalle!,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (accion != null) ...[
                SizedBox(height: compacto ? Espacios.m : Espacios.xl),
                accion!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
