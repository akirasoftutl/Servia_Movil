import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import 'fakes.dart';
import 'utilidades_prueba.dart';

Future<void> abrir(WidgetTester tester, ListaServiceFalso fake) async {
  await tester.pumpWidget(
    MaterialApp(home: ListaNegociosPage(negociosService: fake)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'respeta exactamente el orden, reservas, catálogo y abre el perfil',
    (tester) async {
      // Con el viewport alto se construyen los dos carruseles y la lista final.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = ListaServiceFalso()
        ..responder = (_) async =>
            pagina([resumen('z', acepta: false), resumen('a')]);
      await abrir(tester, fake);
      // Cada negocio se muestra en los dos carruseles y en «Lugares cercanos».
      // Las secciones inferiores quedan fuera de pantalla en el viewport de
      // prueba, por eso se buscan también los widgets offstage.
      expect(find.text('Negocio z', skipOffstage: false), findsNWidgets(3));
      expect(find.text('Negocio a', skipOffstage: false), findsNWidgets(3));
      // En los carruseles el orden es horizontal; en «Lugares cercanos»,
      // vertical. Las tarjetas de esta última usan tipografía de 15 px.
      Finder tarjetaCercana(String nombre) => find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.data == nombre && widget.style?.fontSize == 15,
      );
      expect(
        tester.getTopLeft(find.text('Negocio z').first).dx,
        lessThan(tester.getTopLeft(find.text('Negocio a').first).dx),
      );
      expect(
        tester.getTopLeft(tarjetaCercana('Negocio z')).dy,
        lessThan(tester.getTopLeft(tarjetaCercana('Negocio a')).dy),
      );
      // El estado de reservas se refleja ahora en la etiqueta del carrusel.
      expect(
        find.text('Cabello y barba · Disponible', skipOffstage: false),
        findsNWidgets(2),
      );
      // Una etiqueta más: la de la categoría en la nueva cuadrícula.
      expect(
        find.text('Cabello y barba', skipOffstage: false),
        findsNWidgets(3),
      );
      final titulo = tester.widget<Text>(find.text('Negocio z').first);
      expect(titulo.maxLines, 1);
      expect(titulo.overflow, TextOverflow.ellipsis);
      await tester.tap(find.text('Negocio a').first);
      await tester.pumpAndSettle();
      // El listado abre el perfil con un MaterialPageRoute directo.
      expect(find.byType(PerfilNegocioPage), findsOneWidget);
    },
  );
  testWidgets('usa el id si falla el catálogo', (tester) async {
    final fake = ListaServiceFalso()
      ..errorCategorias = Exception()
      ..responder = (_) async => pagina([resumen('a')]);
    await abrir(tester, fake);
    expect(find.textContaining('cabello'), findsWidgets);
    expect(find.text('Cabello y barba'), findsNothing);
  });
  testWidgets('pagina al desplazarse, no duplica y termina con cursor nulo', (
    tester,
  ) async {
    final pendiente = Completer<PaginaNegocios>();
    final fake = ListaServiceFalso()
      ..responder = (cursor) async => cursor == null
          ? pagina(List.generate(15, (i) => resumen('n$i')), 'dos')
          : pendiente.future;
    await abrir(tester, fake);
    expect(fake.llamadas, [null]);
    await desplazarListaAlFinal(tester);
    await tester.pump();
    expect(fake.llamadas, [null, 'dos']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pendiente.complete(pagina([resumen('ultimo')]));
    await tester.pumpAndSettle();
    expect(find.text('Negocio ultimo'), findsOneWidget);
    await desplazarListaAlFinal(tester);
    expect(fake.llamadas, [null, 'dos']);
  });
  testWidgets('completa páginas cortas sin desplazar ni duplicar peticiones', (
    tester,
  ) async {
    // La portada nueva es más alta que la pantalla de prueba; con un viewport
    // alto se conserva la intención original: completar páginas sin desplazar.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final pendiente = Completer<PaginaNegocios>();
    final fake = ListaServiceFalso()
      ..responder = (cursor) async {
        if (cursor == null) return pagina([resumen('a')], 'dos');
        if (cursor == 'dos') return pendiente.future;
        return pagina([resumen('fin')]);
      };
    await tester.pumpWidget(
      MaterialApp(home: ListaNegociosPage(negociosService: fake)),
    );
    await tester.pump();
    await tester.pump();
    expect(fake.llamadas, [null, 'dos']);
    expect(find.text('Negocio a'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump();
    expect(fake.llamadas, [null, 'dos']);
    pendiente.complete(pagina([resumen('b')], 'tres'));
    await tester.pumpAndSettle();
    expect(fake.llamadas, [null, 'dos', 'tres']);
    expect(find.text('Negocio b'), findsWidgets);
    expect(find.text('Negocio fin'), findsWidgets);
  });
  testWidgets('limita la carga automática y permite continuar páginas vacías', (
    tester,
  ) async {
    final fake = ListaServiceFalso()
      ..responder = (c) async =>
          c == null ? pagina([], 'sigue') : pagina([resumen('a')]);
    await abrir(tester, fake);
    expect(fake.llamadas, [null, 'sigue']);
    expect(find.text('Negocio a'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    final vacio = ListaServiceFalso()
      ..responder = (cursor) async =>
          pagina([], '${cursor == null ? 1 : int.parse(cursor) + 1}');
    await abrir(tester, vacio);
    expect(vacio.llamadas.length, 5);
    expect(find.text(MensajesNegocios.listaVacia), findsNothing);
    expect(find.text(MensajesNegocios.cargarMas), findsOneWidget);
    await tester.tap(find.text(MensajesNegocios.cargarMas));
    await tester.pumpAndSettle();
    expect(vacio.llamadas.length, 10);
  });
  testWidgets(
    'error de segunda página conserva la primera y reintenta su cursor',
    (tester) async {
      final fake = ListaServiceFalso();
      var falla = true;
      fake.responder = (c) async {
        if (c == null) {
          return pagina(List.generate(10, (i) => resumen('n$i')), 'dos');
        }
        if (falla) throw const SocketException('secreto');
        return pagina([resumen('fin')]);
      };
      await abrir(tester, fake);
      await desplazarListaAlFinal(tester);
      await tester.pumpAndSettle();
      expect(find.text('Negocio n9'), findsOneWidget);
      expect(find.text(MensajesNegocios.errorRed), findsOneWidget);
      falla = false;
      await tester.ensureVisible(find.text(MensajesNegocios.reintentar));
      await tester.pumpAndSettle();
      await tester.tap(find.text(MensajesNegocios.reintentar));
      await tester.pumpAndSettle();
      expect(fake.llamadas, [null, 'dos', 'dos']);
      expect(find.text('Negocio fin'), findsOneWidget);
    },
  );
  for (final error in [
    const SocketException('crudo'),
    TimeoutException('crudo'),
    const ApiException(500, 'crudo'),
    const FormatException('crudo'),
  ]) {
    testWidgets('mensaje claro y reintento para ${error.runtimeType}', (
      tester,
    ) async {
      final fake = ListaServiceFalso()..responder = (_) async => throw error;
      await abrir(tester, fake);
      expect(find.text(MensajesNegocios.mensajeDeError(error)), findsOneWidget);
      expect(find.textContaining('crudo'), findsNothing);
      fake.responder = (_) async => pagina([resumen('a')]);
      await tester.tap(find.text(MensajesNegocios.reintentar));
      await tester.pumpAndSettle();
      expect(find.text('Negocio a'), findsWidgets);
    });
  }
  testWidgets('reintenta el cursor que falló después de una página vacía', (
    tester,
  ) async {
    final fake = ListaServiceFalso();
    var falla = true;
    fake.responder = (c) async {
      if (c == null) {
        return pagina(List.generate(10, (i) => resumen('n$i')), 'dos');
      }
      if (c == 'dos') return pagina([], 'tres');
      if (falla) throw const SocketException('crudo');
      return pagina([resumen('fin')]);
    };
    await abrir(tester, fake);
    await desplazarListaAlFinal(tester);
    await tester.pumpAndSettle();
    expect(find.text('Negocio n9'), findsOneWidget);
    await tester.ensureVisible(find.text(MensajesNegocios.reintentar));
    await tester.pumpAndSettle();
    falla = false;
    await tester.tap(find.text(MensajesNegocios.reintentar));
    await tester.pumpAndSettle();
    expect(fake.llamadas, [null, 'dos', 'tres', 'tres']);
    expect(find.text('Negocio fin'), findsOneWidget);
  });
  testWidgets('reintenta el cursor fallido tras una primera página vacía', (
    tester,
  ) async {
    final fake = ListaServiceFalso();
    var falla = true;
    fake.responder = (cursor) async {
      if (cursor == null) return pagina([], 'dos');
      if (falla) throw const SocketException('crudo');
      return pagina([resumen('fin')]);
    };
    await abrir(tester, fake);
    expect(fake.llamadas, [null, 'dos']);
    falla = false;
    await tester.tap(find.text(MensajesNegocios.reintentar));
    await tester.pumpAndSettle();
    expect(fake.llamadas, [null, 'dos', 'dos']);
    expect(find.text('Negocio fin'), findsWidgets);
  });
  testWidgets('lista vacía muestra su mensaje', (tester) async {
    await abrir(tester, ListaServiceFalso());
    expect(find.text(MensajesNegocios.listaVacia), findsOneWidget);
  });
}
