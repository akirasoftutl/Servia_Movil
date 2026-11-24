import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../mensajes.dart';

// Mismos literales de la hoja que ya usaba el mapa de cercanos.
const _borde = Color(0xFFE5E7EB);
const _agarradera = Color(0xFFD1D5DB);

/// Con esta velocidad (px/s) un arrastre corto ya decide hacia dónde va.
const _velocidadDecisiva = 400.0;
const _duracionAjuste = Duration(milliseconds: 260);

/// Hoja de la pestaña Buscar que se desliza sobre el mapa, como en Uber.
///
/// [progreso] vale 1 con la hoja abierta (deja ver una franja del mapa) y 0
/// colapsada (solo el asa y la búsqueda). Se arrastra desde el asa, desde la
/// búsqueda o tirando hacia abajo del contenido cuando ya está arriba del
/// todo; al soltarla se ajusta a la posición más cercana o a la del impulso.
/// El contenido hace scroll normal mientras la hoja está abierta.
class HojaInicio extends StatefulWidget {
  const HojaInicio({
    super.key,
    required this.progreso,
    required this.recorrido,
    required this.activa,
    required this.child,
  });

  final AnimationController progreso;

  /// Distancia en píxeles entre la posición abierta y la colapsada.
  final double recorrido;

  /// Sin mapa la hoja no se arrastra: el contenido ocupa todo, como antes.
  final bool activa;
  final Widget child;

  @override
  State<HojaInicio> createState() => _HojaInicioState();
}

class _HojaInicioState extends State<HojaInicio> {
  bool _arrastreDesdeContenido = false;

  bool get _abierta => widget.progreso.value >= 0.5;

  @override
  void initState() {
    super.initState();
    widget.progreso.addStatusListener(_alCambiarEstado);
  }

  @override
  void didUpdateWidget(covariant HojaInicio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progreso != widget.progreso) {
      oldWidget.progreso.removeStatusListener(_alCambiarEstado);
      widget.progreso.addStatusListener(_alCambiarEstado);
    }
  }

  @override
  void dispose() {
    widget.progreso.removeStatusListener(_alCambiarEstado);
    super.dispose();
  }

  // Solo para actualizar las etiquetas de accesibilidad al quedar en reposo.
  void _alCambiarEstado(AnimationStatus estado) {
    if (estado.isCompleted || estado.isDismissed) setState(() {});
  }

  void _mover(double dy) {
    if (widget.recorrido <= 0) return;
    widget.progreso.value -= dy / widget.recorrido;
  }

  void _irA(double destino) {
    widget.progreso.animateTo(
      destino,
      duration: _duracionAjuste,
      curve: Curves.easeOutCubic,
    );
  }

  /// [velocidad] en px/s, positiva hacia abajo.
  void _asentar(double velocidad) {
    if (velocidad.abs() >= _velocidadDecisiva) {
      _irA(velocidad < 0 ? 1 : 0);
    } else {
      _irA(_abierta ? 1 : 0);
    }
  }

  void _alternar() => _irA(_abierta ? 0 : 1);

  /// Tirar hacia abajo del contenido cuando ya está arriba baja la hoja; el
  /// resto del scroll es del contenido y la hoja no interviene.
  bool _alDesplazar(ScrollNotification aviso) {
    if (aviso.depth != 0 || aviso.metrics.axis != Axis.vertical) return false;
    if (aviso is OverscrollNotification &&
        aviso.dragDetails != null &&
        aviso.overscroll < 0) {
      _arrastreDesdeContenido = true;
      widget.progreso.stop();
      _mover(-aviso.overscroll);
    } else if (aviso is ScrollEndNotification && _arrastreDesdeContenido) {
      _arrastreDesdeContenido = false;
      _asentar(aviso.dragDetails?.velocity.pixelsPerSecond.dy ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.activa) return widget.child;
    final abierta = _abierta;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: abierta
          ? MensajesNegocios.hojaAbierta
          : MensajesNegocios.hojaColapsada,
      child: GestureDetector(
        onVerticalDragStart: (_) => widget.progreso.stop(),
        onVerticalDragUpdate: (detalle) => _mover(detalle.delta.dy),
        onVerticalDragEnd: (detalle) =>
            _asentar(detalle.velocity.pixelsPerSecond.dy),
        onVerticalDragCancel: () => _asentar(0),
        child: NotificationListener<ScrollNotification>(
          onNotification: _alDesplazar,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            // Al tocar la búsqueda con la hoja abajo, sube para ver resultados.
            onFocusChange: (enfocada) {
              if (enfocada && !_abierta) _irA(1);
            },
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(Radios.l),
                ),
                border: Border(top: BorderSide(color: _borde)),
              ),
              child: Column(
                children: [
                  _Asa(abierta: abierta, onTap: _alternar),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barrita gris de la hoja con un área táctil de 48 dp a todo lo ancho.
class _Asa extends StatelessWidget {
  const _Asa({required this.abierta, required this.onTap});

  final bool abierta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: abierta
          ? MensajesNegocios.asaVerMapa
          : MensajesNegocios.asaVerContenido,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('asa-hoja-inicio'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: Medidas.tactil,
          width: double.infinity,
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _agarradera,
                borderRadius: BorderRadius.circular(Radios.s),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
