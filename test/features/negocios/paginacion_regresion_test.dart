import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';

void main() {
  for (final conItems in [false, true]) {
    testWidgets(
      'conserva el cursor tras cinco vacías; lista previa $conItems',
      (tester) async {
        final fake = ListaServiceFalso()
          ..responder = (cursor) async {
            if (conItems && cursor == null) {
              return pagina([resumen('previo')], '1');
            }
            final numero = cursor == null ? 1 : int.parse(cursor);
            if (numero <= 5) return pagina([], '${numero + 1}');
            return pagina([resumen('sexta')]);
          };
        await tester.pumpWidget(
          MaterialApp(home: ListaNegociosPage(negociosService: fake)),
        );
        await tester.pumpAndSettle();
        expect(
          fake.llamadas,
          conItems
              ? [null, '1', '2', '3', '4', '5']
              : [null, '2', '3', '4', '5'],
        );
        expect(find.text(MensajesNegocios.listaVacia), findsNothing);
        expect(find.text(MensajesNegocios.cargarMas), findsOneWidget);
        if (conItems) expect(find.text('Negocio previo'), findsOneWidget);
        await tester.tap(find.text(MensajesNegocios.cargarMas));
        await tester.pumpAndSettle();
        expect(fake.llamadas.last, '6');
        expect(find.text('Negocio sexta'), findsOneWidget);
        if (conItems) expect(find.text('Negocio previo'), findsOneWidget);
        expect(find.text(MensajesNegocios.cargarMas), findsNothing);
        final consultas = fake.llamadas.length;
        await tester.pumpAndSettle();
        expect(fake.llamadas.length, consultas);
      },
    );
  }
}
