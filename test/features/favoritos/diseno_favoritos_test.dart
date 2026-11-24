import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/core/widgets/estados.dart';
import 'package:servia/features/favoritos/mensajes.dart';
import 'package:servia/features/favoritos/pages/favoritos_page.dart';
import 'package:servia/features/favoritos/pages/tarjeta_servicio_favorito.dart';

import '../../core/tema_de_la_app.dart';
import '../negocios/fakes.dart';
import 'fakes_favoritos.dart';

/// Archivos de las issues #64 y #82: el rediseño usa la paleta neutra de la
/// app, con blanco, negro y grises en lugar de la antigua marca naranja.
List<File> archivosDeFavoritos() => [
  ...Directory('lib/features/favoritos')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart')),
];

void main() {
  test('el código de favoritos se queda en la paleta del rediseño', () {
    const permitidos = {'0xFF111827', '0xFFF3F4F6', '0xFF0F0F0F', '0xFFD1D5DB'};
    final literal = RegExp(r'Color\((0x[0-9A-Fa-f]{8})\)');
    for (final archivo in archivosDeFavoritos()) {
      for (final coincidencia in literal.allMatches(
        archivo.readAsStringSync(),
      )) {
        final color = coincidencia.group(1)!;
        expect(
          permitidos,
          contains(color),
          reason: '${archivo.path} introduce $color fuera de la paleta',
        );
      }
    }
  });

  group('los estilos del rediseño', () {
    late ThemeData tema;
    late ApiFavoritosFalsa api;
    late SesionFavoritos sesion;

    setUp(() {
      api = ApiFavoritosFalsa();
      sesion = SesionFavoritos('ana');
    });

    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      tema = temaDeLaApp(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: FavoritosPage(
            controlador: api.controlador(sesion),
            negociosService: NegociosServiceFalso(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pantalla, título y corazón siguen el diseño de la app', (
      tester,
    ) async {
      api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
      await montar(tester);
      final c = tema.colorScheme;

      // Fondo blanco del rediseño, sin AppBar: encabezado propio.
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.white,
      );
      expect(tema.scaffoldBackgroundColor, ColoresServia.fondo);
      expect(find.byType(AppBar), findsNothing);

      // Título grande y negro, con la tipografía de la app.
      final titulo = tester
          .renderObject<RenderParagraph>(find.text(MensajesFavoritos.titulo))
          .text
          .style!;
      expect(titulo.fontFamily, 'PlusJakartaSans');
      expect(titulo.color, const Color(0xFF111827));
      expect(titulo.fontSize, 26);

      // Corazón marcado con el color primario del tema y 48 dp táctiles.
      final corazon = find.byType(IconButton).last;
      expect(find.byTooltip(MensajesFavoritos.quitar), findsOneWidget);
      expect(tester.widget<IconButton>(corazon).isSelected, isTrue);
      expect(
        tester.widget<IconButton>(corazon).style!.foregroundColor!.resolve({}),
        c.primary,
      );
      expect(
        tester.getSize(corazon).shortestSide,
        greaterThanOrEqualTo(Medidas.tactil),
      );
    });

    testWidgets('el aviso al fallar usa el SnackBar del tema', (tester) async {
      api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
      await montar(tester);
      api.errores['DELETE'] = (codigo: 500, mensaje: 'Falló');

      await tester.tap(find.byTooltip(MensajesFavoritos.quitar));
      await tester.pumpAndSettle();

      // Sin colores ni formas propias: el SnackBar toma las del tema.
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, isNull);
      expect(snack.shape, isNull);
      expect(snack.behavior, isNull);
      expect(
        tema.snackBarTheme.backgroundColor,
        tema.colorScheme.inverseSurface,
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, tema.colorScheme.inverseSurface);
    });

    testWidgets('vacío y error usan EstadoVacio y EstadoError del rediseño', (
      tester,
    ) async {
      await montar(tester);
      expect(find.byType(EstadoVacio), findsOneWidget);
      final fondoIcono = tester.widget<Container>(
        find.descendant(
          of: find.byType(EstadoVacio),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).borderRadius ==
                    BorderRadius.circular(Radios.l),
          ),
        ),
      );
      expect(
        (fondoIcono.decoration! as BoxDecoration).color,
        tema.colorScheme.primaryContainer,
      );
    });
  });

  group('favoritos de servicios: píldoras y tarjetas', () {
    late ThemeData tema;
    late ApiFavoritosFalsa api;

    setUp(() {
      api = ApiFavoritosFalsa();
      api
          .serviciosDe('ana')
          .add(servicioFavorito('n1', 's1', nombre: 'Masaje relajante'));
    });

    Future<void> montar(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      tema = temaDeLaApp(tester);
      final sesion = SesionFavoritos('ana');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: FavoritosPage(
            controlador: api.controlador(sesion),
            serviciosControlador: api.controladorServicios(sesion),
            negociosService: NegociosServiceFalso(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(MensajesFavoritos.tabServicios));
      await tester.pumpAndSettle();
    }

    BoxDecoration pildora(WidgetTester tester, String texto) {
      final caja = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text(texto),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return caja.decoration! as BoxDecoration;
    }

    testWidgets('pestañas, tarjeta y corazón usan el diseño de la app', (
      tester,
    ) async {
      await montar(tester);
      final c = tema.colorScheme;

      // Pestañas tipo píldora: negra la activa, blanca la otra, con 48 dp.
      expect(find.byType(TabBar), findsNothing);
      final seleccionada = pildora(tester, MensajesFavoritos.tabServicios);
      expect(seleccionada.color, const Color(0xFF0F0F0F));
      expect(seleccionada.borderRadius, BorderRadius.circular(30));
      expect(
        (seleccionada.border! as Border).top.color,
        const Color(0xFF0F0F0F),
      );
      final otra = pildora(tester, MensajesFavoritos.tabNegocios);
      expect(otra.color, Colors.white);
      expect((otra.border! as Border).top.color, const Color(0xFFD1D5DB));
      final area = find
          .ancestor(
            of: find.text(MensajesFavoritos.tabServicios),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.height == Medidas.tactil,
            ),
          )
          .first;
      expect(tester.getSize(area).height, Medidas.tactil);

      // Texto activo en blanco sobre la píldora negra.
      final textoSeleccionado = tester
          .renderObject<RenderParagraph>(
            find.text(MensajesFavoritos.tabServicios),
          )
          .text
          .style!;
      expect(textoSeleccionado.color, Colors.white);
      expect(textoSeleccionado.fontFamily, 'PlusJakartaSans');

      // Tarjeta: superficie, borde y radio de tarjeta del tema.
      final tarjeta = tester.widget<Container>(
        find.descendant(
          of: find.byType(TarjetaServicioFavorito),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).border != null,
          ),
        ),
      );
      final decoracion = tarjeta.decoration! as BoxDecoration;
      expect(decoracion.color, c.surface);
      expect(decoracion.borderRadius, Radios.tarjeta);
      expect((decoracion.border! as Border).top.color, c.outlineVariant);

      // Nombre con la fuente y el color del tema.
      final nombre = tester
          .renderObject<RenderParagraph>(find.text('Masaje relajante'))
          .text
          .style!;
      expect(nombre.fontFamily, 'PlusJakartaSans');
      expect(nombre.color, c.onSurface);

      // Corazón marcado con el primario y área táctil de 48 dp.
      final corazon = find.byType(IconButton).last;
      expect(tester.widget<IconButton>(corazon).isSelected, isTrue);
      expect(
        tester.widget<IconButton>(corazon).style!.foregroundColor!.resolve({}),
        c.primary,
      );
      expect(
        tester.getSize(corazon).shortestSide,
        greaterThanOrEqualTo(Medidas.tactil),
      );
    });

    testWidgets('vacío y error de servicios usan EstadoVacio y EstadoError', (
      tester,
    ) async {
      api.serviciosPorCuenta.clear();
      await montar(tester);
      expect(find.byType(EstadoVacio), findsOneWidget);

      api.erroresServicios['GET'] = (codigo: 500, mensaje: 'Falló');
      final sesion = SesionFavoritos('ana');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          theme: tema,
          home: FavoritosPage(
            controlador: api.controlador(sesion),
            serviciosControlador: api.controladorServicios(sesion),
            negociosService: NegociosServiceFalso(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(MensajesFavoritos.tabServicios));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoError), findsOneWidget);
    });
  });
}
