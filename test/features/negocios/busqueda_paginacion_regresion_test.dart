import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';
import 'utilidades_prueba.dart';

void main() {
  testWidgets('continúa la sexta página sin perder búsqueda ni categoría', (
    tester,
  ) async {
    final fake = ListaServiceFalso();
    fake.responder = (cursor) async {
      final filtro = fake.filtros.last;
      if (filtro.q == null && filtro.categoriaId == null) {
        // Semilla para que la cuadrícula de categorías esté en pantalla.
        return pagina([resumen('inicial')]);
      }
      final numero = cursor == null ? 1 : int.parse(cursor);
      if (numero <= 5) return pagina([], '${numero + 1}');
      return pagina([resumen('encontrado')]);
    };
    await tester.pumpWidget(
      MaterialApp(home: ListaNegociosPage(negociosService: fake)),
    );
    await tester.pumpAndSettle();
    await elegirCategoria(tester, 'Cabello y barba');
    await tester.enterText(find.byType(TextField), 'corte');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text(MensajesNegocios.sinResultados), findsNothing);
    expect(find.text(MensajesNegocios.cargarMas), findsOneWidget);
    await tester.tap(find.text(MensajesNegocios.cargarMas));
    await tester.pumpAndSettle();
    expect(fake.llamadas.sublist(fake.llamadas.length - 6), [
      null,
      '2',
      '3',
      '4',
      '5',
      '6',
    ]);
    expect(
      fake.filtros.sublist(fake.filtros.length - 6),
      List.filled(6, (q: 'corte', categoriaId: 'cabello')),
    );
    expect(find.text('Negocio encontrado'), findsOneWidget);
  });
}
