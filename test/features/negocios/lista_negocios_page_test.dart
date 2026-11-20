import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';

Future<void> abrir(WidgetTester tester, ListaServiceFalso fake) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ListaNegociosPage(negociosService: fake),
      onGenerateRoute: (r) =>
          MaterialPageRoute<void>(builder: (_) => Text('Ruta ${r.name}')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'respeta exactamente el orden, reservas, catálogo y abre el perfil',
    (tester) async {
      final fake = ListaServiceFalso()
        ..responder = (_) async =>
            pagina([resumen('z', acepta: false), resumen('a')]);
      await abrir(tester, fake);
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(
        tester.getTopLeft(find.text('Negocio z')).dy,
        lessThan(tester.getTopLeft(find.text('Negocio a')).dy),
      );
      expect(find.text(MensajesNegocios.aceptaReservas), findsOneWidget);
      expect(find.text(MensajesNegocios.noAceptaReservas), findsOneWidget);
      expect(find.text('Cabello y barba'), findsNWidgets(2));
      final titulo = tester.widget<Text>(find.text('Negocio z'));
      expect(titulo.maxLines, 2);
      expect(titulo.overflow, TextOverflow.ellipsis);
      await tester.tap(find.text('Negocio a'));
      await tester.pumpAndSettle();
      expect(find.text('Ruta /negocios/a'), findsOneWidget);
    },
  );
  testWidgets('usa el id si falla el catálogo', (tester) async {
    final fake = ListaServiceFalso()
      ..errorCategorias = Exception()
      ..responder = (_) async => pagina([resumen('a')]);
    await abrir(tester, fake);
    expect(find.text('cabello'), findsOneWidget);
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
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(fake.llamadas, [null, 'dos']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pendiente.complete(pagina([resumen('ultimo')]));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Negocio ultimo'), findsOneWidget);
    expect(fake.llamadas, [null, 'dos']);
  });
  testWidgets('completa páginas cortas sin desplazar ni duplicar peticiones', (
    tester,
  ) async {
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
    expect(find.text('Negocio a'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump();
    expect(fake.llamadas, [null, 'dos']);
    pendiente.complete(pagina([resumen('b')], 'tres'));
    await tester.pumpAndSettle();
    expect(fake.llamadas, [null, 'dos', 'tres']);
    expect(find.text('Negocio b'), findsOneWidget);
    expect(find.text('Negocio fin'), findsOneWidget);
  });
  testWidgets('limita la carga automática y permite continuar páginas vacías', (
    tester,
  ) async {
    final fake = ListaServiceFalso()
      ..responder = (c) async =>
          c == null ? pagina([], 'sigue') : pagina([resumen('a')]);
    await abrir(tester, fake);
    expect(fake.llamadas, [null, 'sigue']);
    expect(find.text('Negocio a'), findsOneWidget);
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
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
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
      expect(find.text('Negocio a'), findsOneWidget);
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
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
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
    expect(find.text('Negocio fin'), findsOneWidget);
  });
  testWidgets('lista vacía muestra su mensaje', (tester) async {
    await abrir(tester, ListaServiceFalso());
    expect(find.text(MensajesNegocios.listaVacia), findsOneWidget);
  });
}
