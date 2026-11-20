import 'dart:async';
import 'dart:convert' show base64;
import 'dart:typed_data';
import 'dart:ui' show Codec;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/data/negocio.dart';
import 'package:servia/features/negocios/pages/fotos_negocio.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import 'datos_prueba.dart';
import 'fakes.dart';

// PNG de 1x1 para que las imágenes de prueba se decodifiquen sin red.
final Uint8List _png = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
);

final Map<String, dynamic> _perfilConFotos = negocioJson()
  ..['fotos'] = fotosJson(
    portada: fotoJson('p1', 'https://fotos.test/portada.jpg'),
    galeria: [
      for (var indice = 1; indice <= 5; indice++)
        fotoJson('g$indice', 'https://fotos.test/g$indice.jpg'),
    ],
  );

Future<void> _mostrarPerfil(
  WidgetTester tester,
  Map<String, dynamic> json, {
  ProveedorImagenNegocio proveedor = NetworkImage.new,
}) async {
  final servicio = NegociosServiceFalso()
    ..pendiente = (Completer<Negocio>()..complete(Negocio.fromJson(json)));
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilNegocioPage(
        negocioId: 'abc123',
        negociosService: servicio,
        proveedorFotos: proveedor,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ProveedorQueFalla extends ImageProvider<_ProveedorQueFalla> {
  @override
  Future<_ProveedorQueFalla> obtainKey(ImageConfiguration configuration) =>
      Future<_ProveedorQueFalla>.value(this);

  @override
  ImageStreamCompleter loadBuffer(
    _ProveedorQueFalla key,
    DecoderBufferCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: Future<Codec>.error(StateError('No se pudo cargar la foto')),
    scale: 1,
  );
}

void main() {
  group('fotos en el perfil del negocio', () {
    testWidgets('muestra la portada arriba y una galería deslizable', (
      tester,
    ) async {
      await _mostrarPerfil(
        tester,
        _perfilConFotos,
        proveedor: (_) => MemoryImage(_png),
      );

      expect(find.byType(PortadaNegocio), findsOneWidget);
      expect(find.byType(GaleriaFotosNegocio), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(6));
      expect(
        tester.getBottomLeft(find.byType(PortadaNegocio)).dy,
        lessThan(tester.getTopLeft(find.text('Salón Aurora')).dy),
      );

      final galeriaScrollable = find.descendant(
        of: find.byType(GaleriaFotosNegocio),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.widget<Scrollable>(galeriaScrollable).axisDirection,
        AxisDirection.right,
      );
      final posicion = tester.state<ScrollableState>(galeriaScrollable).position;
      await tester.drag(
        find.byKey(const Key('foto-galeria-0')),
        const Offset(-300, 0),
      );
      await tester.pumpAndSettle();
      expect(posicion.pixels, greaterThan(0));

      // El resto del perfil sigue presente.
      expect(find.text('Horario de atención'), findsOneWidget);
      expect(find.text('Servicios'), findsOneWidget);
    });

    testWidgets('sin fotos no hay hueco ni sección de galería', (tester) async {
      await _mostrarPerfil(tester, negocioJson());

      expect(find.byType(PortadaNegocio), findsNothing);
      expect(find.byType(GaleriaFotosNegocio), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      expect(find.text('Galería'), findsNothing);
      expect(tester.getTopLeft(find.text('Salón Aurora')).dy, lessThan(100));
      expect(find.text('Horario de atención'), findsOneWidget);
      expect(find.text('Servicios'), findsOneWidget);
    });

    testWidgets('una imagen que falla muestra el marcador neutro', (
      tester,
    ) async {
      await _mostrarPerfil(
        tester,
        _perfilConFotos,
        proveedor: (_) => _ProveedorQueFalla(),
      );

      expect(find.byType(PortadaNegocio), findsOneWidget);
      expect(find.byType(GaleriaFotosNegocio), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsNWidgets(6));
      expect(find.text('Salón Aurora'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
