import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';

void main() {
  for (final conItems in [false, true]) {
    testWidgets('cursor repetido se detiene y se recupera; items $conItems', (
      tester,
    ) async {
      var recuperado = false;
      final fake = ListaServiceFalso()
        ..responder = (cursor) async {
          if (cursor == null) return pagina([], 'igual');
          if (recuperado) return pagina([resumen('recuperado')]);
          return pagina(conItems ? [resumen('duplicado')] : [], 'igual');
        };
      await tester.pumpWidget(
        MaterialApp(home: ListaNegociosPage(negociosService: fake)),
      );
      // Bombeos limitados: también terminan si la versión defectuosa hace bucle.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(fake.llamadas, [null, 'igual']);
      expect(find.text(MensajesNegocios.reintentar), findsOneWidget);
      expect(find.text('Negocio duplicado'), findsNothing);
      expect(find.text(MensajesNegocios.listaVacia), findsNothing);
      recuperado = true;
      await tester.tap(find.text(MensajesNegocios.reintentar));
      await tester.pumpAndSettle();
      expect(fake.llamadas, [null, 'igual', 'igual']);
      expect(find.text('Negocio recuperado'), findsOneWidget);
    });
  }
}
