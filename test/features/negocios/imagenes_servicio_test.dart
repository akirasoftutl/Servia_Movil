import 'dart:convert' show base64, jsonEncode;
import 'dart:typed_data';
import 'dart:ui' show Codec;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/data/servicio.dart';
import 'package:servia/features/negocios/pages/detalle_servicio_page.dart';
import 'package:servia/features/negocios/pages/imagenes_servicio.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import '../../core/tema_de_la_app.dart';
import 'datos_prueba.dart';
import 'fakes.dart';

// PNG de 1x1 para que las imágenes de prueba se decodifiquen sin red.
final Uint8List _png = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
);

class _ProveedorQueFalla extends ImageProvider<_ProveedorQueFalla> {
  @override
  Future<_ProveedorQueFalla> obtainKey(ImageConfiguration configuration) =>
      Future<_ProveedorQueFalla>.value(this);

  @override
  ImageStreamCompleter loadBuffer(
    _ProveedorQueFalla key,
    DecoderBufferCallback decode,
  ) => MultiFrameImageStreamCompleter(
    codec: Future<Codec>.error(StateError('No se pudo cargar la imagen')),
    scale: 1,
  );
}

// Respuesta real de GET /negocios/{id}/servicios/{servicioId} (Servia_BE#114
// y #120): trae `imagenes` y, además, los campos de categoría de Móvil#76.
Map<String, dynamic> servicioApiJson({
  List<Map<String, dynamic>>? imagenes = const [],
}) => {
  'id': 's2',
  'nombre': 'Z Corte',
  'descripcion': 'Lavado y corte de cabello',
  'precio': 150.5,
  'duracionMin': 90,
  'imagenes': ?imagenes,
  'categoriaServicio': {
    'id': 'corte-caballero',
    'nombre': 'Corte de caballero',
  },
  'categoriaPersonalizada': null,
};

List<Map<String, dynamic>> _imagenes(int n) => [
  for (var i = 1; i <= n; i++)
    fotoJson('img$i', 'https://supabase.test/servicios/s2/img$i.jpg'),
];

Servicio _servicioConImagenes(int n) =>
    Servicio.fromJson(servicioApiJson(imagenes: _imagenes(n)));

Future<void> _mostrarDetalle(
  WidgetTester tester,
  Servicio servicio, {
  ImageProvider Function(String url)? proveedor,
  ThemeData? tema,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final negocios = _ServicioFijo(servicio);
  await tester.pumpWidget(
    MaterialApp(
      theme: tema,
      home: DetalleServicioPage(
        negocioId: 'abc123',
        servicioId: 's2',
        aceptaReservas: true,
        negocioNombre: 'Negocio de prueba',
        negociosService: negocios,
        proveedorImagenes: proveedor ?? (_) => MemoryImage(_png),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ServicioFijo extends DetalleServiceFalso {
  _ServicioFijo(this.fijo);
  final Servicio fijo;
  @override
  Future<Servicio> obtenerServicio(String negocioId, String servicioId) async =>
      fijo;
}

void main() {
  group('modelo: imágenes del servicio (HU-C32, T19)', () {
    test('lee imagenes {id, url} en orden y tolera campos extra', () {
      final servicio = _servicioConImagenes(3);
      expect(servicio.imagenes.map((i) => i.id), ['img1', 'img2', 'img3']);
      expect(
        servicio.imagenes.first.url,
        'https://supabase.test/servicios/s2/img1.jpg',
      );
      expect(servicio.nombre, 'Z Corte');
      expect(servicio.descripcion, 'Lavado y corte de cabello');
    });

    test('imagenes [] o ausente (API anterior) es lista vacía', () {
      expect(Servicio.fromJson(servicioApiJson()).imagenes, isEmpty);
      expect(
        Servicio.fromJson(servicioApiJson(imagenes: null)).imagenes,
        isEmpty,
      );
      expect(serviciosPrueba.first.imagenes, isEmpty);
    });

    test('imagenes malformado se ignora sin romper el servicio', () {
      for (final malo in <Object?>[
        null,
        'x',
        4,
        {'url': 'a'},
      ]) {
        final servicio = Servicio.fromJson({
          ...servicioApiJson(),
          'imagenes': malo,
        });
        expect(servicio.imagenes, isEmpty);
        expect(servicio.id, 's2');
      }
      final mezcla = Servicio.fromJson({
        ...servicioApiJson(),
        'imagenes': [
          fotoJson('a', 'https://x.test/a.jpg'),
          'roto',
          {'id': 'b'},
          {'id': 'c', 'url': ''},
          fotoJson('d', 'https://x.test/d.jpg'),
        ],
      });
      expect(mezcla.imagenes.map((i) => i.id), ['a', 'd']);
    });

    test('el servicio de la lista y del detalle traen las imágenes', () async {
      final cliente = NegociosService(
        api: ApiClient(
          client: MockClient((peticion) async {
            final esLista = peticion.url.path.endsWith('/servicios');
            final cuerpo = servicioApiJson(imagenes: _imagenes(2));
            return http.Response(jsonEncode(esLista ? [cuerpo] : cuerpo), 200);
          }),
        ),
      );
      expect(
        (await cliente.obtenerServicios('abc123')).single.imagenes,
        hasLength(2),
      );
      expect(
        (await cliente.obtenerServicio('abc123', 's2')).imagenes,
        hasLength(2),
      );
    });
  });

  group('detalle del servicio con imágenes', () {
    testWidgets(
      'con varias imágenes las muestra arriba del nombre y se deslizan',
      (tester) async {
        await _mostrarDetalle(tester, _servicioConImagenes(3));

        expect(find.byType(ImagenesServicio), findsOneWidget);
        expect(find.byKey(const Key('imagen-servicio-0')), findsOneWidget);
        expect(
          tester.getBottomLeft(find.byType(ImagenesServicio)).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.text('Z Corte')).dy),
        );
        final scrollable = find.descendant(
          of: find.byType(ImagenesServicio),
          matching: find.byType(Scrollable),
        );
        expect(
          tester.widget<Scrollable>(scrollable).axisDirection,
          AxisDirection.right,
        );
        final posicion = tester.state<ScrollableState>(scrollable).position;
        await tester.drag(
          find.byKey(const Key('imagen-servicio-0')),
          const Offset(-250, 0),
        );
        await tester.pumpAndSettle();
        expect(posicion.pixels, greaterThan(0));
        expect(find.text('Z Corte'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('con una imagen ocupa el ancho y no se desliza', (
      tester,
    ) async {
      await _mostrarDetalle(tester, _servicioConImagenes(1));
      expect(find.byKey(const Key('imagen-servicio-0')), findsOneWidget);
      expect(find.byKey(const Key('imagen-servicio-1')), findsNothing);
      final scrollable = find.descendant(
        of: find.byType(ImagenesServicio),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        0,
      );
    });

    testWidgets('sin imágenes no hay franja, hueco ni marcador', (
      tester,
    ) async {
      await _mostrarDetalle(tester, _servicioConImagenes(0));
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.image_outlined), findsNothing);
      expect(find.byKey(const Key('imagen-servicio-0')), findsNothing);
      expect(tester.getSize(find.byType(ImagenesServicio)), Size.zero);
      expect(find.text('Z Corte'), findsOneWidget);
      expect(find.text('Reservar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'una imagen que no carga muestra el marcador y la pantalla sigue',
      (tester) async {
        final semantica = tester.ensureSemantics();
        await _mostrarDetalle(
          tester,
          _servicioConImagenes(2),
          proveedor: (_) => _ProveedorQueFalla(),
        );
        expect(find.byIcon(Icons.image_outlined), findsAtLeastNWidgets(1));
        expect(
          find.bySemanticsLabel(RegExp('Imagen no disponible')),
          findsAtLeastNWidgets(1),
        );
        expect(find.text('Z Corte'), findsOneWidget);
        expect(find.text('Reservar'), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantica.dispose();
      },
    );

    testWidgets('cada imagen tiene texto alternativo con su posición', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await _mostrarDetalle(tester, _servicioConImagenes(3));
      expect(find.bySemanticsLabel('Imagen 1 de 3 de Z Corte'), findsOneWidget);
      expect(find.bySemanticsLabel('Imagen 2 de 3 de Z Corte'), findsOneWidget);
      semantica.dispose();
    });
  });

  group('estilos de las imágenes salen del tema', () {
    testWidgets('marcador y esquinas usan el esquema y los radios del tema', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final tema = temaDeLaApp(tester);
      await _mostrarDetalle(
        tester,
        _servicioConImagenes(1),
        proveedor: (_) => _ProveedorQueFalla(),
        tema: tema,
      );
      final marcador = tester.widget<Container>(
        find.descendant(
          of: find.byType(ImagenesServicio),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.color != null,
          ),
        ),
      );
      expect(marcador.color, tema.colorScheme.surfaceContainerHighest);
      expect(marcador.color, ColoresServia.superficieMasHundida);
      final icono = tester.widget<Icon>(find.byIcon(Icons.image_outlined));
      expect(icono.color, tema.colorScheme.onSurfaceVariant);
      final recorte = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byKey(const Key('imagen-servicio-0')),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(recorte.borderRadius, BorderRadius.circular(Radios.m));
    });

    testWidgets('si cambia el esquema del tema, cambia el marcador', (
      tester,
    ) async {
      final otro = ThemeData(
        colorScheme: ColoresServia.esquema.copyWith(
          surfaceContainerHighest: const Color(0xFF123456),
        ),
      );
      await _mostrarDetalle(
        tester,
        _servicioConImagenes(1),
        proveedor: (_) => _ProveedorQueFalla(),
        tema: otro,
      );
      final marcador = tester.widget<Container>(
        find.descendant(
          of: find.byType(ImagenesServicio),
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.color != null,
          ),
        ),
      );
      expect(marcador.color, const Color(0xFF123456));
    });
  });

  group('fila del servicio en el perfil del negocio', () {
    Future<void> perfil(
      WidgetTester tester,
      List<Servicio> servicios, {
      ImageProvider Function(String url)? proveedor,
    }) async {
      final fake = ServiciosServiceFalso()..servicios = servicios;
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilNegocioPage(
            negocioId: 'abc123',
            negociosService: fake,
            proveedorFotos: proveedor ?? (_) => MemoryImage(_png),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Servicios'));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra la miniatura de la primera imagen solo si tiene', (
      tester,
    ) async {
      await perfil(tester, [
        _servicioConImagenes(2),
        const Servicio(
          id: 's1',
          nombre: 'A Masaje',
          precio: 150,
          duracionMin: 30,
        ),
      ]);
      expect(find.byKey(const Key('miniatura-servicio-s2')), findsOneWidget);
      expect(find.byKey(const Key('miniatura-servicio-s1')), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('miniatura-servicio-s2'))),
        const Size.square(Medidas.miniatura),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('con texto grande la fila deja el ancho al nombre y al botón', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await perfil(tester, [_servicioConImagenes(2)]);
      expect(find.byKey(const Key('miniatura-servicio-s2')), findsNothing);
      expect(find.text('Z Corte'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una miniatura que falla no rompe la fila', (tester) async {
      await perfil(tester, [
        _servicioConImagenes(1),
      ], proveedor: (_) => _ProveedorQueFalla());
      expect(find.text('Z Corte'), findsOneWidget);
      expect(find.byKey(const Key('miniatura-servicio-s2')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
