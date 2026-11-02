import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/categoria.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';

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
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nombre).last);
  await tester.pumpAndSettle();
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
      expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 50);
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
    await abrir(tester, fake);
    final selector = tester.widget<DropdownButton<String>>(
      find.byType(DropdownButton<String>),
    );
    expect(selector.items!.map((c) => c.value), ['', 'a', 'b']);
    await categoria(tester, 'Segunda');
    expect(fake.llamadas.last, null);
    expect(fake.filtros.last.categoriaId, 'b');
    expect(find.text(MensajesNegocios.sinResultados), findsOneWidget);
    await categoria(tester, MensajesNegocios.todas);
    expect(fake.filtros.last.categoriaId, null);
    expect(find.text(MensajesNegocios.listaVacia), findsOneWidget);
  });
  testWidgets('catálogo fallido oculta selector y conserva búsqueda', (
    tester,
  ) async {
    final fake = ListaServiceFalso()..errorCategorias = Exception();
    await abrir(tester, fake);
    expect(find.byType(DropdownButton<String>), findsNothing);
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
      await escribir(tester, 'uñas');
      await categoria(tester, 'Cabello y barba');
      expect(fake.llamadas.last, null);
      expect(fake.filtros.last, (q: 'uñas', categoriaId: 'cabello'));
      await tester.drag(find.byType(ListView), const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(fake.llamadas.last, 'dos');
      expect(fake.filtros.last, (q: 'uñas', categoriaId: 'cabello'));
      expect(find.text('Negocio fin'), findsOneWidget);
      await tester.tap(find.byTooltip(MensajesNegocios.limpiar));
      await tester.pumpAndSettle();
      expect(fake.llamadas.last, null);
      expect(fake.filtros.last, (q: null, categoriaId: 'cabello'));
      await categoria(tester, MensajesNegocios.todas);
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
    await tester.tap(find.byTooltip(MensajesNegocios.limpiar));
    await tester.pumpAndSettle();
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
    final fake = ListaServiceFalso()
      ..responder = (cursor) async {
        if (cursor == null) return pagina([resumen('a')], 'dos');
        throw const ApiException(400, 'cuerpo crudo');
      };
    await abrir(tester, fake);
    expect(fake.llamadas, [null, 'dos']);
    expect(find.text('Negocio a'), findsOneWidget);
    expect(find.text(MensajesNegocios.busquedaInvalida), findsOneWidget);
    expect(find.text(MensajesNegocios.reintentar), findsNothing);
    fake.responder = (_) async => pagina([resumen('corregida')]);
    await categoria(tester, 'Cabello y barba');
    expect(fake.llamadas.last, null);
    expect(find.text('Negocio corregida'), findsOneWidget);
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
