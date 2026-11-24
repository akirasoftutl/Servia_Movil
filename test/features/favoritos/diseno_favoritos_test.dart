import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/core/widgets/estados.dart';
import 'package:servia/features/favoritos/mensajes.dart';
import 'package:servia/features/favoritos/pages/favoritos_page.dart';

import '../../core/tema_de_la_app.dart';
import '../negocios/fakes.dart';
import 'fakes_favoritos.dart';

/// Archivos de la issue #64 que no deben traer colores, tamaños de letra,
/// radios ni espacios literales: todo sale del tema y de los tokens.
List<File> archivosDeFavoritos() => [
  ...Directory('lib/features/favoritos')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart')),
];

void main() {
  test(
    'el código de favoritos no usa colores, radios ni espacios literales',
    () {
      final prohibidos = {
        'Color(0x': RegExp(r'Color\(\s*0x|Color\.from'),
        'Colors.': RegExp(r'\bColors\.(?!transparent)'),
        'fontSize': RegExp(r'fontSize\s*:'),
        'fontWeight': RegExp(r'fontWeight\s*:'),
        'BorderRadius.circular': RegExp(
          r'BorderRadius\.circular|Radius\.circular',
        ),
        'EdgeInsets numérico': RegExp(r'EdgeInsets\.\w+\([^)]*(?<![\w.])\d'),
        'SizedBox numérico': RegExp(r'(width|height|dimension)\s*:\s*\d'),
      };
      for (final archivo in archivosDeFavoritos()) {
        final texto = archivo.readAsStringSync();
        for (final MapEntry(key: nombre, value: patron) in prohibidos.entries) {
          expect(
            patron.hasMatch(texto),
            isFalse,
            reason: '${archivo.path} usa $nombre literal',
          );
        }
      }
    },
  );

  group('los estilos salen del tema de Servia', () {
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

    testWidgets(
      'pantalla, texto y corazón usan colores, fuente y radios del tema',
      (tester) async {
        api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
        await montar(tester);
        final c = tema.colorScheme;

        // Fondo de la pantalla: el del tema.
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          isNull,
        );
        expect(tema.scaffoldBackgroundColor, ColoresServia.fondo);

        // Título de la barra con la fuente y el estilo del tema.
        final titulo = tester
            .renderObject<RenderParagraph>(find.text(MensajesFavoritos.titulo))
            .text
            .style!;
        expect(titulo.fontFamily, 'PlusJakartaSans');
        expect(titulo.color, c.onSurface);
        expect(titulo.fontSize, tema.textTheme.titleLarge!.fontSize);
        expect(
          tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
          isNull,
        );

        // Corazón marcado con el color primario del tema.
        final corazon = tester.widget<IconButton>(find.byType(IconButton));
        expect(corazon.isSelected, isTrue);
        expect(corazon.style!.foregroundColor!.resolve({}), c.primary);
        expect(
          tester.getSize(find.byType(IconButton)).shortestSide,
          greaterThanOrEqualTo(Medidas.tactil),
        );
      },
    );

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
}
