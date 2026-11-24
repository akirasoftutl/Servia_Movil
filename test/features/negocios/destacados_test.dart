import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/core/widgets/estados.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/data/orden_negocios.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';
import 'package:servia/features/negocios/pages/seccion_destacados.dart';

import '../../core/tema_de_la_app.dart';
import 'fakes.dart';
import 'fakes_destacados.dart';
import 'utilidades_prueba.dart';

NegociosService servicioCon(
  Future<http.Response> Function(http.Request) responder,
) => NegociosService(api: ApiClient(client: MockClient(responder)));

/// Lista con el tema real de la app, como la ve el cliente.
Future<void> abrir(WidgetTester tester, ListaConDestacados fake) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  final tema = temaDeLaApp(tester);
  await tester.pumpWidget(
    MaterialApp(theme: tema, home: ListaNegociosPage(negociosService: fake)),
  );
  await tester.pumpAndSettle();
}

ListaConDestacados conDestacados() => ListaConDestacados()
  ..destacados = [destacado('d2'), destacado('d1', categoriaId: null)]
  ..responder = (_) async => pagina([resumen('a'), resumen('b')]);

Finder tituloSeccion() => find.text(MensajesNegocios.destacados);

void main() {
  group('NegociosService.obtenerDestacados', () {
    test('pide GET /negocios/destacados sin token ni parámetros', () async {
      final servicio = servicioCon((peticion) async {
        expect(peticion.method, 'GET');
        expect(
          peticion.url.toString(),
          '${ApiClient.baseUrl}/negocios/destacados',
        );
        expect(peticion.url.hasQuery, isFalse);
        expect(peticion.headers.containsKey('Authorization'), isFalse);
        return http.Response(
          jsonEncode({
            'items': [
              destacadoJson('x2', portada: 'https://img.test/x2.jpg'),
              destacadoJson('x1', categoriaId: null, aceptaReservas: false),
            ],
          }),
          200,
        );
      });
      final negocios = await servicio.obtenerDestacados();
      expect(negocios.map((n) => n.id), ['x2', 'x1'], reason: 'orden de la API');
      expect(negocios.first.imagenUrl, 'https://img.test/x2.jpg');
      expect(negocios.first.categoriaId, 'cabello');
      expect(negocios.last.categoriaId, isNull);
      expect(negocios.last.aceptaReservas, isFalse);
    });

    test('sin Completadas la API devuelve items vacío', () async {
      final servicio = servicioCon(
        (_) async => http.Response('{"items":[]}', 200),
      );
      expect(await servicio.obtenerDestacados(), isEmpty);
    });

    test('un 500 es ApiException y una forma inválida es FormatException', () async {
      await expectLater(
        servicioCon(
          (_) async => http.Response('dato privado', 500),
        ).obtenerDestacados(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'estado', 500)
              .having((e) => e.mensaje, 'mensaje', isNot(contains('privado'))),
        ),
      );
      await expectLater(
        servicioCon(
          (_) async => http.Response('{"items":"no"}', 200),
        ).obtenerDestacados(),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('sección «Destacados» del inicio', () {
    testWidgets('muestra la sección con las tarjetas en el orden de la API', (
      tester,
    ) async {
      await abrir(tester, conDestacados());
      expect(tituloSeccion(), findsOneWidget);
      expect(find.byType(SeccionDestacados), findsOneWidget);
      final d2 = tester.getTopLeft(find.text('Destacado d2'));
      final d1 = tester.getTopLeft(find.text('Destacado d1'));
      expect(d2.dx, lessThan(d1.dx), reason: 'd2 va primero, como la API');
      expect(d2.dy, d1.dy, reason: 'fila horizontal');
      // La categoría sale del catálogo que ya carga la lista; sin categoría
      // (null) la tarjeta no muestra ninguna.
      expect(
        find.descendant(
          of: find.byType(SeccionDestacados),
          matching: find.text('Cabello y barba'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('el carrusel ya no sale de los primeros de la lista', (
      tester,
    ) async {
      await abrir(tester, conDestacados());
      expect(find.text('Recomendado'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SeccionDestacados),
          matching: find.text('Negocio a'),
        ),
        findsNothing,
      );
    });

    testWidgets('tocar una tarjeta abre el perfil de ese negocio', (
      tester,
    ) async {
      await abrir(tester, conDestacados());
      await tester.tap(find.text('Destacado d2'));
      await tester.pumpAndSettle();
      final perfil = tester.widget<PerfilNegocioPage>(
        find.byType(PerfilNegocioPage),
      );
      expect(perfil.negocioId, 'd2');
    });

    testWidgets('sin destacados no hay sección y la lista funciona', (
      tester,
    ) async {
      final fake = conDestacados()..destacados = [];
      await abrir(tester, fake);
      expect(tituloSeccion(), findsNothing);
      expect(find.byType(SeccionDestacados), findsNothing);
      expect(find.text('Negocio a'), findsWidgets);
      expect(find.byType(EstadoError), findsNothing);
    });

    testWidgets('si la consulta falla no hay sección ni error visible', (
      tester,
    ) async {
      final fake = conDestacados()..errorDestacados = const ApiException(500, 'x');
      await abrir(tester, fake);
      expect(fake.consultasDestacados, 1);
      expect(tituloSeccion(), findsNothing);
      expect(find.byType(EstadoError), findsNothing);
      expect(find.text(MensajesNegocios.errorApi), findsNothing);
      expect(find.text('Negocio a'), findsWidgets);
    });

    testWidgets('la lista aparece sin esperar a los destacados', (tester) async {
      final pendientes = Completer<List<NegocioResumen>>();
      final fake = conDestacados()..destacadosPendientes = pendientes;
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: ListaNegociosPage(negociosService: fake)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Negocio a'), findsWidgets);
      expect(tituloSeccion(), findsNothing);
      pendientes.complete([destacado('d1')]);
      await tester.pumpAndSettle();
      expect(tituloSeccion(), findsOneWidget);
    });

    testWidgets('con una búsqueda activa no se muestra y vuelve al limpiarla', (
      tester,
    ) async {
      final fake = conDestacados();
      await abrir(tester, fake);
      expect(tituloSeccion(), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'aur');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(tituloSeccion(), findsNothing);
      expect(find.byType(SeccionDestacados), findsNothing);
      await limpiarBusqueda(tester);
      expect(tituloSeccion(), findsOneWidget);
    });

    testWidgets('con una categoría elegida no se muestra y vuelve con «Todo»', (
      tester,
    ) async {
      await abrir(tester, conDestacados());
      await elegirCategoria(tester, 'Cabello y barba');
      expect(tituloSeccion(), findsNothing);
      await elegirCategoria(tester, 'Todo');
      expect(tituloSeccion(), findsOneWidget);
    });

    testWidgets('consulta una vez al abrir y de nuevo al refrescar la lista', (
      tester,
    ) async {
      final fake = conDestacados();
      await abrir(tester, fake);
      expect(fake.consultasDestacados, 1);
      // Cambiar el orden no cambia los destacados: no se vuelven a pedir.
      fake.ordenes.clear();
      await tester.tap(find.byType(PopupMenuButton<OrdenNegocios>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(MensajesNegocios.ordenRecientes).last);
      await tester.pumpAndSettle();
      expect(fake.ordenes, isNotEmpty);
      expect(fake.consultasDestacados, 1);
      // Refrescar (volver a la lista sin filtros) sí los consulta otra vez.
      await elegirCategoria(tester, 'Cabello y barba');
      expect(fake.consultasDestacados, 1, reason: 'oculta: no se consulta');
      await elegirCategoria(tester, 'Todo');
      expect(fake.consultasDestacados, 2);
    });

    testWidgets('si falla al refrescar la sección se oculta', (tester) async {
      final fake = conDestacados();
      await abrir(tester, fake);
      expect(tituloSeccion(), findsOneWidget);
      fake.errorDestacados = const ApiException(500, 'x');
      await elegirCategoria(tester, 'Cabello y barba');
      await elegirCategoria(tester, 'Todo');
      expect(tituloSeccion(), findsNothing);
      expect(find.text('Negocio a'), findsWidgets);
    });
  });

  group('estilos de la sección salen del tema', () {
    Future<void> montar(WidgetTester tester, ThemeData tema) => tester.pumpWidget(
      MaterialApp(
        theme: tema,
        home: Scaffold(
          body: SeccionDestacados(
            negocios: [destacado('d1'), destacado('d2')],
            nombreCategoria: (_) => 'Cabello y barba',
            onAbrir: (_) {},
          ),
        ),
      ),
    );

    testWidgets('el título usa titleLarge del tema y el margen de Espacios', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final tema = temaDeLaApp(tester);
      await montar(tester, tema);
      final titulo = tester.widget<Text>(tituloSeccion());
      expect(titulo.style, tema.textTheme.titleLarge);
      expect(tester.getTopLeft(tituloSeccion()).dx, Espacios.l);
      final semantica = tester.ensureSemantics();
      addTearDown(semantica.dispose);
      expect(
        tester.getSemantics(tituloSeccion()),
        matchesSemantics(label: MensajesNegocios.destacados, isHeader: true),
      );
    });

    testWidgets('cambia con el tema: ningún estilo es literal', (tester) async {
      await tester.pumpWidget(const SizedBox());
      final base = temaDeLaApp(tester);
      final otro = base.copyWith(
        textTheme: base.textTheme.copyWith(
          titleLarge: base.textTheme.titleLarge!.copyWith(
            color: const Color(0xFF123456),
            fontSize: 31,
          ),
        ),
      );
      await montar(tester, otro);
      final titulo = tester.widget<Text>(tituloSeccion());
      expect(titulo.style!.color, const Color(0xFF123456));
      expect(titulo.style!.fontSize, 31);
      expect(titulo.style!.color, isNot(ColoresServia.texto));
    });
  });
}
