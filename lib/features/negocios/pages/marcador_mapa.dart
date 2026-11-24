import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/colores_servia.dart';
import '../data/ubicacion_cliente.dart';
import '../data/ubicacion_negocio.dart';

// Mismo negro de píldora ya usado en `mapa_negocio.dart`.
const _fondoPin = Color(0xFF0F0F0F);
const _zoomPorOmision = 14.0;
const _zoomMinimo = 10.0;
const _zoomMaximo = 16.0;

/// Resultado en PNG de una píldora de distancia dibujada en canvas.
typedef ImagenPinMapa = ({
  Uint8List bytes,
  int anchoPx,
  int altoPx,
  double escala,
});

/// Calcula un nivel de zoom inicial centrado en [centro] que abarque todas
/// las [ubicaciones] cercanas con margen para la hoja inferior.
double calcularZoomInicial(
  PosicionCliente centro,
  Iterable<UbicacionNegocio> ubicaciones,
) {
  var maxDeltaLat = 0.0;
  var maxDeltaLng = 0.0;
  var hayUbicaciones = false;
  for (final u in ubicaciones) {
    hayUbicaciones = true;
    final dLat = (u.lat - centro.lat).abs();
    final dLng = (u.lng - centro.lng).abs();
    if (dLat > maxDeltaLat) maxDeltaLat = dLat;
    if (dLng > maxDeltaLng) maxDeltaLng = dLng;
  }
  if (!hayUbicaciones) return _zoomPorOmision;

  final cosenoLat = math.cos(centro.lat * math.pi / 180).abs().clamp(0.2, 1.0);
  final extension = math.max(maxDeltaLat * 2.6, (maxDeltaLng / cosenoLat) * 2.6);
  if (extension <= 0) return 15.5;
  final zoom = math.log(360.0 / extension) / math.ln2;
  return zoom.clamp(_zoomMinimo, _zoomMaximo).toDouble();
}

/// Renderiza una píldora de distancia en PNG respetando la densidad de pantalla.
/// Sin seleccionar: píldora negra con texto blanco; seleccionada: más grande y
/// en el morado de acento [ColoresServia.morado].
Future<ImagenPinMapa> dibujarPinDistanciaPng({
  required String etiqueta,
  required bool seleccionado,
  double pixelRatio = 1.0,
}) async {
  final escala = pixelRatio.isFinite ? pixelRatio.clamp(1.0, 4.0) : 1.0;
  final fontSize = seleccionado ? 14.0 : 12.5;
  final paddingH = seleccionado ? 14.0 : 11.0;
  final paddingV = seleccionado ? 8.0 : 6.0;
  final grosorBorde = seleccionado ? 2.0 : 1.5;
  const margenSombra = 4.0;

  final painter = TextPainter(
    text: TextSpan(
      text: etiqueta,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        height: 1.1,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();

  final anchoPildora = painter.width + paddingH * 2;
  final altoPildora = painter.height + paddingV * 2;
  final anchoLogico = anchoPildora + margenSombra * 2;
  final altoLogico = altoPildora + margenSombra * 2;

  final anchoPx = (anchoLogico * escala).ceil();
  final altoPx = (altoLogico * escala).ceil();

  final grabadora = ui.PictureRecorder();
  final canvas = Canvas(grabadora);
  canvas.scale(escala);

  final rect = Rect.fromLTWH(
    margenSombra,
    margenSombra - 1,
    anchoPildora,
    altoPildora,
  );
  final pildora = RRect.fromRectAndRadius(
    rect,
    Radius.circular(altoPildora / 2),
  );

  final sombra = Paint()
    ..color = Colors.black.withValues(alpha: seleccionado ? 0.32 : 0.24)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
  canvas.drawRRect(pildora.shift(const Offset(0, 1.5)), sombra);

  final relleno = Paint()
    ..color = seleccionado ? ColoresServia.morado : _fondoPin
    ..style = PaintingStyle.fill;
  canvas.drawRRect(pildora, relleno);

  final borde = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = grosorBorde;
  canvas.drawRRect(pildora, borde);

  final origenTexto = Offset(
    rect.left + (rect.width - painter.width) / 2,
    rect.top + (rect.height - painter.height) / 2,
  );
  painter.paint(canvas, origenTexto);

  final dibujo = grabadora.endRecording();
  final imagen = await dibujo.toImage(anchoPx, altoPx);
  final data = await imagen.toByteData(format: ui.ImageByteFormat.png);
  imagen.dispose();
  dibujo.dispose();

  return (
    bytes: data!.buffer.asUint8List(),
    anchoPx: anchoPx,
    altoPx: altoPx,
    escala: escala,
  );
}

Future<BitmapDescriptor> crearMarcadorDistancia({
  required String etiqueta,
  required bool seleccionado,
  double pixelRatio = 1.0,
}) async {
  final resultado = await dibujarPinDistanciaPng(
    etiqueta: etiqueta,
    seleccionado: seleccionado,
    pixelRatio: pixelRatio,
  );
  return BitmapDescriptor.bytes(
    resultado.bytes,
    imagePixelRatio: resultado.escala,
  );
}

/// Dibuja el punto de posición del cliente (solo desde la lectura en memoria).
Future<BitmapDescriptor> crearMarcadorCliente({double pixelRatio = 1.0}) async {
  final escala = pixelRatio.isFinite ? pixelRatio.clamp(1.0, 4.0) : 1.0;
  const tamanoLogico = 32.0;
  const centro = Offset(tamanoLogico / 2, tamanoLogico / 2);
  final ladoPx = (tamanoLogico * escala).ceil();

  final grabadora = ui.PictureRecorder();
  final canvas = Canvas(grabadora);
  canvas.scale(escala);

  canvas.drawCircle(
    centro,
    14,
    Paint()..color = ColoresServia.morado.withValues(alpha: 0.22),
  );
  canvas.drawCircle(centro, 8, Paint()..color = Colors.white);
  canvas.drawCircle(centro, 5.5, Paint()..color = ColoresServia.morado);

  final dibujo = grabadora.endRecording();
  final imagen = await dibujo.toImage(ladoPx, ladoPx);
  final data = await imagen.toByteData(format: ui.ImageByteFormat.png);
  imagen.dispose();
  dibujo.dispose();

  return BitmapDescriptor.bytes(
    data!.buffer.asUint8List(),
    imagePixelRatio: escala,
  );
}
