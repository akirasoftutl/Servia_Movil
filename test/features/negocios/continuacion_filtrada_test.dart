import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';
import 'utilidades_prueba.dart';

Future<void> filtrar(WidgetTester tester, bool texto, bool categoria) async {
  // La cuadrícula de categorías solo existe mientras hay resultados: elegir
  // primero la categoría y después escribir mantiene ambos filtros vivos.
  if (categoria) {
    await elegirCategoria(tester, 'Cabello y barba');
  }
  if (texto) {
    await tester.enterText(find.byType(TextField), 'corte');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final (texto, categoria) in [
    (true, false),
    (false, true),
    (true, true),
  ]) {
    testWidgets('continuación con filtros q=$texto categoría=$categoria', (
      tester,
    ) async {
      final pendiente = Completer<PaginaNegocios>();
      var recuperar = false;
      final fake = ListaServiceFalso();
      fake.responder = (cursor) async {
        final filtro = fake.filtros.last;
        if (filtro.q == null && filtro.categoriaId == null) {
          // Resultado inicial: hace falta para que exista la cuadrícula.
          return pagina([resumen('inicial')]);
        }
        final numero = cursor == null ? 1 : int.parse(cursor);
        if (numero <= 5) return pagina([], '${numero + 1}');
        return recuperar ? pagina([resumen('recuperado')]) : pendiente.future;
      };
      await tester.pumpWidget(
        MaterialApp(home: ListaNegociosPage(negociosService: fake)),
      );
      await tester.pumpAndSettle();
      await filtrar(tester, texto, categoria);
      final inicio = fake.llamadas.length - 5;
      await tester.tap(find.text(MensajesNegocios.cargarMas));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(MensajesNegocios.sinResultados), findsNothing);
      expect(find.text(MensajesNegocios.listaVacia), findsNothing);
      pendiente.completeError(const SocketException('sin conexión'));
      await tester.pumpAndSettle();
      expect(find.text(MensajesNegocios.errorRed), findsOneWidget);
      expect(find.text(MensajesNegocios.reintentar), findsOneWidget);
      expect(find.text(MensajesNegocios.sinResultados), findsNothing);
      expect(find.text(MensajesNegocios.listaVacia), findsNothing);
      recuperar = true;
      await tester.tap(find.text(MensajesNegocios.reintentar));
      await tester.pumpAndSettle();
      expect(fake.llamadas.sublist(inicio), [
        null,
        '2',
        '3',
        '4',
        '5',
        '6',
        '6',
      ]);
      expect(
        fake.filtros.sublist(inicio),
        List.filled(7, (
          q: texto ? 'corte' : null,
          categoriaId: categoria ? 'cabello' : null,
        )),
      );
      expect(find.text('Negocio recuperado'), findsWidgets);
    });
  }

  testWidgets('cursor repetido con filtros permite reintentar sin duplicados', (
    tester,
  ) async {
    var recuperar = false;
    final fake = ListaServiceFalso();
    fake.responder = (cursor) async {
      final filtro = fake.filtros.last;
      if (filtro.q == null && filtro.categoriaId == null) {
        return pagina([resumen('inicial')]);
      }
      if (cursor == null) return pagina([], 'igual');
      if (recuperar) return pagina([resumen('recuperado')]);
      return pagina([], 'igual');
    };
    await tester.pumpWidget(
      MaterialApp(home: ListaNegociosPage(negociosService: fake)),
    );
    await tester.pumpAndSettle();
    await filtrar(tester, true, true);
    final inicio = fake.llamadas.length - 2;
    expect(find.text(MensajesNegocios.reintentar), findsOneWidget);
    expect(find.text('Negocio duplicado'), findsNothing);
    recuperar = true;
    await tester.tap(find.text(MensajesNegocios.reintentar));
    await tester.pumpAndSettle();
    expect(fake.llamadas.sublist(inicio), [null, 'igual', 'igual']);
    expect(
      fake.filtros.sublist(inicio),
      List.filled(3, (q: 'corte', categoriaId: 'cabello')),
    );
    expect(find.text('Negocio recuperado'), findsOneWidget);
  });
}
