import 'dart:convert' show jsonEncode;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/data/servicio.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/detalle_servicio_page.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import '../../core/tema_de_la_app.dart';
import 'fakes.dart';

// Formas EXACTAS de la API (Servia_BE#120): las lecturas públicas de servicios
// traen `categoriaServicio` ({id, nombre} o null) y `categoriaPersonalizada`
// (texto o null); a lo sumo uno de los dos tiene valor.
Map<String, dynamic> _json(
  String id,
  String nombre, {
  Map<String, dynamic>? categoriaServicio,
  String? categoriaPersonalizada,
  bool conCampos = true,
}) => {
  'id': id,
  'nombre': nombre,
  'descripcion': 'Descripción de $nombre',
  'precio': 150,
  'duracionMin': 60,
  'imagenes': <Map<String, dynamic>>[],
  if (conCampos) 'categoriaServicio': categoriaServicio,
  if (conCampos) 'categoriaPersonalizada': categoriaPersonalizada,
};

const _corte = {'id': 'corte-caballero', 'nombre': 'Corte de caballero'};
const _barba = {'id': 'barba', 'nombre': 'Barba y afeitado'};

Servicio _servicio(
  String id,
  String nombre, {
  Map<String, dynamic>? categoria,
  String? personalizada,
}) => Servicio.fromJson(
  _json(
    id,
    nombre,
    categoriaServicio: categoria,
    categoriaPersonalizada: personalizada,
  ),
);

class _Fijo extends DetalleServiceFalso {
  _Fijo(List<Servicio> lista) {
    servicios = lista;
  }

  @override
  Future<Servicio> obtenerServicio(String negocioId, String servicioId) async =>
      servicios.firstWhere((s) => s.id == servicioId);
}

NegociosService _api(Object cuerpo) => NegociosService(
  api: ApiClient(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode(cuerpo),
        200,
        headers: {'content-type': 'application/json'},
      ),
    ),
  ),
);

Future<void> _perfil(
  WidgetTester tester,
  List<Servicio> servicios, {
  ThemeData? tema,
  _Fijo? servicio,
}) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: tema,
      home: PerfilNegocioPage(
        negocioId: 'abc123',
        negociosService: servicio ?? _Fijo(servicios),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(MensajesNegocios.servicios));
  await tester.pumpAndSettle();
}

/// Color de relleno del chip: el `chipTheme` lo pinta con un `Ink`.
Color? _fondoChip(WidgetTester tester, String texto) {
  final tinta = tester.widget<Ink>(
    find.descendant(of: _chip(texto), matching: find.byType(Ink)).first,
  );
  return (tinta.decoration as ShapeDecoration).color;
}

Finder _chips() => find.byType(ChoiceChip);
Finder _chip(String texto) =>
    find.widgetWithText(ChoiceChip, texto, skipOffstage: false);

void main() {
  group('modelo: categorías del servicio (T18, T19)', () {
    test('lee categoriaServicio {id, nombre} y personalizada nula', () {
      final s = Servicio.fromJson(
        _json('s1', 'Corte', categoriaServicio: _corte),
      );
      expect(s.categoriaServicio?.id, 'corte-caballero');
      expect(s.categoriaServicio?.nombre, 'Corte de caballero');
      expect(s.categoriaPersonalizada, isNull);
    });

    test('lee categoriaPersonalizada y catálogo nulo', () {
      final s = Servicio.fromJson(
        _json('s1', 'Corte', categoriaPersonalizada: 'Cortes de autor'),
      );
      expect(s.categoriaServicio, isNull);
      expect(s.categoriaPersonalizada, 'Cortes de autor');
    });

    test('servicio viejo (null en ambos) o sin los campos se ve como hoy', () {
      for (final json in [
        _json('s1', 'Corte'),
        _json('s1', 'Corte', conCampos: false),
      ]) {
        final s = Servicio.fromJson(json);
        expect(s.categoriaServicio, isNull);
        expect(s.categoriaPersonalizada, isNull);
        expect(s.nombre, 'Corte');
      }
    });

    test('campos malformados se ignoran sin romper el servicio', () {
      // La personalizada solo es válida como texto; un texto sí es válido.
      for (final malo in <Object?>[
        4,
        true,
        <Object?>[],
        {'id': 'a'},
      ]) {
        final s = Servicio.fromJson({
          ..._json('s1', 'Corte'),
          'categoriaServicio': malo,
          'categoriaPersonalizada': malo,
        });
        expect(s.categoriaServicio, isNull);
        expect(s.categoriaPersonalizada, isNull);
      }
      for (final malo in <Object?>[
        'x',
        4,
        {'nombre': 'b'},
        {'id': 'a'},
      ]) {
        final s = Servicio.fromJson({
          ..._json('s1', 'Corte'),
          'categoriaServicio': malo,
        });
        expect(s.categoriaServicio, isNull);
        expect(s.nombre, 'Corte');
      }
      final vacia = Servicio.fromJson(
        _json('s1', 'Corte', categoriaPersonalizada: '   '),
      );
      expect(vacia.categoriaPersonalizada, isNull);
    });

    test(
      'NegociosService trae las categorías en la lista y en el detalle',
      () async {
        final lista = await _api([
          _json('s1', 'Corte', categoriaServicio: _corte),
          _json('s2', 'Peinado', categoriaPersonalizada: 'Peinados de gala'),
          _json('s3', 'Masaje'),
        ]).obtenerServicios('abc123');
        expect(lista[0].categoriaServicio?.nombre, 'Corte de caballero');
        expect(lista[1].categoriaPersonalizada, 'Peinados de gala');
        expect(lista[2].categoriaServicio, isNull);
        final detalle = await _api(
          _json('s1', 'Corte', categoriaServicio: _corte),
        ).obtenerServicio('abc123', 's1');
        expect(detalle.categoriaServicio?.id, 'corte-caballero');
      },
    );
  });

  group('filtro por categoría en el perfil del negocio', () {
    final varias = [
      _servicio('s1', 'Corte clásico', categoria: _corte),
      _servicio('s2', 'Perfilado', categoria: _barba),
      _servicio('s3', 'Corte fade', categoria: _corte),
      _servicio('s4', 'Peinado de gala', personalizada: 'Peinados de gala'),
      _servicio('s5', 'Masaje'),
    ];

    testWidgets('chips Todas + una por categoría de catálogo, sin repetir', (
      tester,
    ) async {
      await _perfil(tester, varias);
      expect(_chips(), findsNWidgets(3));
      expect(_chip(MensajesNegocios.todas), findsOneWidget);
      expect(_chip('Corte de caballero'), findsOneWidget);
      expect(_chip('Barba y afeitado'), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(_chip(MensajesNegocios.todas)).selected,
        isTrue,
      );
      expect(find.text('Corte clásico'), findsOneWidget);
      expect(find.text('Masaje'), findsOneWidget);
    });

    testWidgets(
      'elegir una categoría deja solo sus servicios y Todas restaura',
      (tester) async {
        final fake = _Fijo(varias);
        await _perfil(tester, varias, servicio: fake);
        await tester.tap(_chip('Corte de caballero'));
        await tester.pumpAndSettle();
        expect(find.text('Corte clásico'), findsOneWidget);
        expect(find.text('Corte fade'), findsOneWidget);
        expect(find.text('Perfilado'), findsNothing);
        expect(find.text('Peinado de gala'), findsNothing);
        expect(find.text('Masaje'), findsNothing);
        expect(
          tester.widget<ChoiceChip>(_chip('Corte de caballero')).selected,
          isTrue,
        );
        // Sin recargar: sigue siendo la misma consulta.
        expect(fake.consultasServicios, 1);

        await tester.tap(_chip('Barba y afeitado'));
        await tester.pumpAndSettle();
        expect(find.text('Perfilado'), findsOneWidget);
        expect(find.text('Corte clásico'), findsNothing);

        await tester.tap(_chip(MensajesNegocios.todas));
        await tester.pumpAndSettle();
        for (final nombre in [
          'Corte clásico',
          'Perfilado',
          'Corte fade',
          'Peinado de gala',
          'Masaje',
        ]) {
          expect(find.text(nombre), findsOneWidget);
        }
        expect(fake.consultasServicios, 1);
      },
    );

    testWidgets('sin categorías de catálogo no hay fila de chips', (
      tester,
    ) async {
      await _perfil(tester, [
        _servicio('s1', 'Corte'),
        _servicio('s2', 'Masaje'),
      ]);
      expect(_chips(), findsNothing);
      expect(find.text(MensajesNegocios.todas), findsNothing);
      expect(find.text('Corte'), findsOneWidget);
      expect(find.text('Masaje'), findsOneWidget);
    });

    testWidgets('la personalizada se ve en el servicio pero no es chip', (
      tester,
    ) async {
      await _perfil(tester, [
        _servicio('s1', 'Peinado', personalizada: 'Peinados de gala'),
        _servicio('s2', 'Corte', categoria: _corte),
      ]);
      expect(_chips(), findsNWidgets(2)); // Todas + Corte de caballero
      expect(_chip('Peinados de gala'), findsNothing);
      expect(find.byKey(const Key('categoria-servicio-s1')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('categoria-servicio-s1')),
          matching: find.text('Peinados de gala'),
        ),
        findsOneWidget,
      );
      // Con el filtro de catálogo activo, el de categoría personalizada sale.
      await tester.tap(_chip('Corte de caballero'));
      await tester.pumpAndSettle();
      expect(find.text('Peinado'), findsNothing);
    });

    testWidgets('solo personalizadas: sin chips y el texto se ve', (
      tester,
    ) async {
      await _perfil(tester, [
        _servicio('s1', 'Peinado', personalizada: 'Peinados de gala'),
      ]);
      expect(_chips(), findsNothing);
      expect(find.text('Peinados de gala'), findsOneWidget);
    });

    testWidgets('la fila muestra la categoría de catálogo; sin ella, nada', (
      tester,
    ) async {
      await _perfil(tester, varias);
      expect(
        find.descendant(
          of: find.byKey(const Key('categoria-servicio-s1')),
          matching: find.text('Corte de caballero'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('categoria-servicio-s5')), findsNothing);
    });

    testWidgets('conserva el filtro al volver del detalle del servicio', (
      tester,
    ) async {
      await _perfil(tester, varias);
      await tester.tap(_chip('Barba y afeitado'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(MensajesNegocios.reservar));
      await tester.pumpAndSettle();
      expect(find.byType(DetalleServicioPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(DetalleServicioPage))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(MensajesNegocios.servicios));
      expect(
        tester.widget<ChoiceChip>(_chip('Barba y afeitado')).selected,
        isTrue,
      );
      expect(find.text('Perfilado'), findsOneWidget);
      expect(find.text('Corte clásico'), findsNothing);
    });

    testWidgets('no pide el catálogo /categorias-servicio', (tester) async {
      final rutas = <String>[];
      final service = NegociosService(
        api: ApiClient(
          client: MockClient((peticion) async {
            rutas.add(peticion.url.path);
            return http.Response(
              jsonEncode([_json('s1', 'Corte', categoriaServicio: _corte)]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      final lista = await service.obtenerServicios('abc123');
      expect(lista, hasLength(1));
      expect(rutas, ['/negocios/abc123/servicios']);
    });
  });

  group('detalle del servicio', () {
    Future<void> detalle(
      WidgetTester tester,
      Servicio s, {
      ThemeData? tema,
    }) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: DetalleServicioPage(
            negocioId: 'abc123',
            servicioId: s.id,
            aceptaReservas: true,
            negocioNombre: 'Salón Aurora',
            negociosService: _Fijo([s]),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra la categoría de catálogo', (tester) async {
      await detalle(tester, _servicio('s1', 'Corte', categoria: _corte));
      expect(
        find.descendant(
          of: find.byKey(const Key('categoria-servicio')),
          matching: find.text('Corte de caballero'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('muestra la categoría personalizada', (tester) async {
      await detalle(
        tester,
        _servicio('s1', 'Corte', personalizada: 'Cortes de autor'),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('categoria-servicio')),
          matching: find.text('Cortes de autor'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sin categoría no muestra nada ni deja hueco', (tester) async {
      await detalle(tester, _servicio('s1', 'Corte'));
      expect(find.byKey(const Key('categoria-servicio')), findsNothing);
      expect(find.text('Corte'), findsOneWidget);
    });
  });

  group('estilos de las categorías salen del tema', () {
    testWidgets('chips, texto y tamaño táctil usan tokens del tema', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final tema = temaDeLaApp(tester);
      await _perfil(tester, [
        _servicio('s1', 'Corte clásico', categoria: _corte),
        _servicio('s2', 'Perfilado', categoria: _barba),
      ], tema: tema);

      Color? fondo(String texto) => _fondoChip(tester, texto);
      expect(
        fondo('Corte de caballero'),
        tema.colorScheme.surfaceContainerHigh,
      );
      expect(fondo('Corte de caballero'), ColoresServia.superficieHundida);
      await tester.tap(_chip('Corte de caballero'));
      await tester.pumpAndSettle();
      expect(fondo('Corte de caballero'), tema.colorScheme.primaryContainer);
      expect(fondo('Corte de caballero'), ColoresServia.primarioContenedor);

      final alto = tester.getSize(_chip('Corte de caballero')).height;
      final area = tester
          .getSize(
            find
                .ancestor(
                  of: _chip('Corte de caballero'),
                  matching: find.byType(ConstrainedBox),
                )
                .first,
          )
          .height;
      expect(alto >= Medidas.tactil || area >= Medidas.tactil, isTrue);

      final texto = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('categoria-servicio-s1')),
          matching: find.text('Corte de caballero'),
        ),
      );
      expect(texto.style?.color, tema.colorScheme.onSurfaceVariant);
      expect(texto.style?.color, ColoresServia.textoSuave);
      expect(texto.style?.fontFamily, 'PlusJakartaSans');
    });

    testWidgets('si cambia el esquema del tema, cambian chip y texto', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final base = temaDeLaApp(tester);
      final otro = base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          onSurfaceVariant: const Color(0xFF654321),
        ),
        chipTheme: base.chipTheme.copyWith(
          selectedColor: const Color(0xFF123456),
        ),
      );
      await _perfil(tester, [
        _servicio('s1', 'Corte clásico', categoria: _corte),
      ], tema: otro);
      await tester.tap(_chip('Corte de caballero'));
      await tester.pumpAndSettle();
      final fondo = _fondoChip(tester, 'Corte de caballero');
      expect(fondo, const Color(0xFF123456));
      final texto = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('categoria-servicio-s1')),
          matching: find.text('Corte de caballero'),
        ),
      );
      expect(texto.style?.color, const Color(0xFF654321));
    });

    testWidgets('la selección se anuncia a los lectores de pantalla', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await _perfil(tester, [
        _servicio('s1', 'Corte clásico', categoria: _corte),
      ]);
      expect(
        tester.getSemantics(_chip(MensajesNegocios.todas)),
        matchesSemantics(
          label: MensajesNegocios.todas,
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      semantica.dispose();
    });
  });
}
