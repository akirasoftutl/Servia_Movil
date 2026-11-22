import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/categoria.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';
import 'utilidades_prueba.dart';

Future<void> abrir(WidgetTester tester, ListaServiceFalso fake) async {
  await tester.pumpWidget(
    MaterialApp(home: ListaNegociosPage(negociosService: fake)),
  );
  await tester.pumpAndSettle();
}

Future<void> escribir(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> categoria(WidgetTester tester, String nombre) async {
  await elegirCategoria(tester, nombre);
}

void main() {
  testWidgets(
    'espera cuatrocientos milisegundos desde la última letra y recorta espacios',
    (tester) async {
      final fake = ListaServiceFalso();
      await abrir(tester, fake);
      await tester.enterText(find.byType(TextField), 'Ca');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), ' Café  ');
      await tester.pump(const Duration(milliseconds: 399));
      expect(fake.llamadas.length, 1);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(fake.llamadas, [null, null]);
      expect(fake.filtros.last.q, 'Café');
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.decoration?.hintText, 'Explorar todos los servicios');
      expect(campo.textInputAction, TextInputAction.search);
      await escribir(tester, ' a ');
      expect(fake.filtros.last.q, null);
      expect(find.text(MensajesNegocios.listaVacia), findsOneWidget);
    },
  );
  testWidgets('descarta éxitos y errores viejos incluso durante la espera', (
    tester,
  ) async {
    final vieja = Completer<PaginaNegocios>();
    final otra = Completer<PaginaNegocios>();
    final fake = ListaServiceFalso();
    fake.responder = (_) async {
      if (fake.filtros.last.q == 'vieja') return vieja.future;
      if (fake.filtros.last.q == 'otra') return otra.future;
      return pagina([resumen('nueva')]);
    };
    await abrir(tester, fake);
    await tester.enterText(find.byType(TextField), 'vieja');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await escribir(tester, 'nueva');
    vieja.complete(pagina([resumen('obsoleta')]));
    await tester.pumpAndSettle();
    expect(find.text('Negocio nueva'), findsOneWidget);
    expect(find.text('Negocio obsoleta'), findsNothing);
    await tester.enterText(find.byType(TextField), 'otra');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'final');
    otra.completeError(const ApiException(500, 'crudo'));
    await tester.pump();
    expect(find.text(MensajesNegocios.errorApi), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Negocio nueva'), findsOneWidget);
  });
  testWidgets('selector usa solo categorías activas en orden del catálogo', (
    tester,
  ) async {
    final fake = ListaServiceFalso()
      ..categorias = const [
        Categoria(id: 'b', nombre: 'Segunda', orden: 2, activo: true),
        Categoria(id: 'x', nombre: 'Oculta', orden: 0, activo: false),
        Categoria(id: 'a', nombre: 'Primera', orden: 1, activo: true),
      ];
    fake.responder = (_) async {
      final filtro = fake.filtros.last;
      if (filtro.q == null && filtro.categoriaId == null) {
        return pagina([resumen('inicial')]);
      }
      return pagina([]);
    };
    await abrir(tester, fake);
    final opciones = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Text),
    );
    expect(
      tester.widgetList<Text>(opciones).map((texto) => texto.data).toList(),
      ['Todo', 'Primera', 'Segunda'],
    );
    expect(find.text('Oculta'), findsNothing);
    await categoria(tester, 'Segunda');
    expect(fake.llamadas.last, null);
    expect(fake.filtros.last.categoriaId, 'b');
    expect(find.text(MensajesNegocios.sinResultados), findsOneWidget);
    // Sin resultados la cuadrícula desaparece: refrescamos con un item para
    // volver a tener el botón «Todo» y comprobar que limpia la categoría.
    fake.responder = (_) async => pagina([resumen('con-categoria')]);
    await escribir(tester, 'x');
    await limpiarBusqueda(tester);
    expect(find.byType(GridView), findsOneWidget);
    fake.responder = (_) async => pagina([]);
    await categoria(tester, 'Todo');
    expect(fake.filtros.last.categoriaId, null);
    expect(find.text(MensajesNegocios.listaVacia), findsOneWidget);
  });
  testWidgets('catálogo fallido oculta selector y conserva búsqueda', (
    tester,
  ) async {
    final fake = ListaServiceFalso()..errorCategorias = Exception();
    await abrir(tester, fake);
    expect(find.byType(GridView), findsNothing);
    await escribir(tester, 'uñas');
    expect(fake.filtros.last.q, 'uñas');
    expect(find.text(MensajesNegocios.sinResultados), findsOneWidget);
  });
  testWidgets(
    'combina filtros, conserva ambos al paginar y reinicia al limpiar',
    (tester) async {
      final fake = ListaServiceFalso()
        ..responder = (c) async => c == null
            ? pagina(List.generate(15, (i) => resumen('n$i')), 'dos')
            : pagina([resumen('fin')]);
      await abrir(tester, fake);
      // La cuadrícula de categorías desaparece cuando hay texto de búsqueda.
      await categoria(tester, 'Cabello y barba');
      await escribir(tester, 'uñas');
      expect(fake.llamadas.last, null);
      expect(fake.filtros.last, (q: 'uñas', categoriaId: 'cabello'));
      await tester.drag(listaVertical(), const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(fake.llamadas.last, 'dos');
      expect(fake.filtros.last, (q: 'uñas', categoriaId: 'cabello'));
      expect(find.text('Negocio fin'), findsOneWidget);
      await limpiarBusqueda(tester);
      expect(fake.llamadas.last, null);
      expect(fake.filtros.last, (q: null, categoriaId: 'cabello'));
      await categoria(tester, 'Todo');
      expect(fake.filtros.last, (q: null, categoriaId: null));
      expect(fake.llamadas.last, null);
    },
  );
  testWidgets('texto nuevo reinicia cursor y mensaje de búsqueda vacía', (
    tester,
  ) async {
    final fake = ListaServiceFalso()
      ..responder = (_) async => pagina([resumen('a')], 'dos');
    await abrir(tester, fake);
    fake.responder = (_) async => pagina([]);
    await escribir(tester, 'inexistente');
    expect(fake.llamadas.last, null);
    expect(find.text(MensajesNegocios.sinResultados), findsOneWidget);
    expect(find.text(MensajesNegocios.listaVacia), findsNothing);
    await limpiarBusqueda(tester);
    expect(find.text(MensajesNegocios.listaVacia), findsOneWidget);
  });
  testWidgets(
    'un cuatrocientos muestra aviso sin reintentar y permite corregir',
    (tester) async {
      final fake = ListaServiceFalso();
      await abrir(tester, fake);
      fake.responder = (_) async =>
          throw const ApiException(400, 'cuerpo crudo');
      await escribir(tester, '++');
      expect(find.text(MensajesNegocios.busquedaInvalida), findsOneWidget);
      expect(find.textContaining('crudo'), findsNothing);
      expect(find.text(MensajesNegocios.reintentar), findsNothing);
      fake.responder = (_) async => pagina([resumen('corregida')]);
      await escribir(tester, 'correcta');
      expect(find.text('Negocio corregida'), findsOneWidget);
      expect(find.text(MensajesNegocios.busquedaInvalida), findsNothing);
    },
  );
  testWidgets('un cuatrocientos al paginar conserva lista sin reintentar', (
    tester,
  ) async {
    // Con un viewport alto la portada no llena la pantalla y la lista sigue
    // completando sola la página corta, como antes del rediseño.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = ListaServiceFalso()
      ..responder = (cursor) async {
        if (cursor == null) return pagina([resumen('a')], 'dos');
        throw const ApiException(400, 'cuerpo crudo');
      };
    await abrir(tester, fake);
    expect(fake.llamadas, [null, 'dos']);
    expect(find.text('Negocio a'), findsWidgets);
    expect(find.text(MensajesNegocios.busquedaInvalida), findsOneWidget);
    expect(find.text(MensajesNegocios.reintentar), findsNothing);
    fake.responder = (_) async => pagina([resumen('corregida')]);
    await categoria(tester, 'Cabello y barba');
    expect(fake.llamadas.last, null);
    expect(find.text('Negocio corregida'), findsWidgets);
  });
  testWidgets('libera espera y descarta petición al desmontar', (tester) async {
    final fake = ListaServiceFalso();
    await abrir(tester, fake);
    await tester.enterText(find.byType(TextField), 'pendiente');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(fake.llamadas.length, 1);
    final pendiente = Completer<PaginaNegocios>();
    fake.responder = (_) => pendiente.future;
    await tester.pumpWidget(
      MaterialApp(home: ListaNegociosPage(negociosService: fake)),
    );
    await tester.pumpWidget(const SizedBox());
    pendiente.complete(pagina([]));
    await tester.pump();
    expect(tester.takeException(), null);
  });
}
