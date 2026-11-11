import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';

void main() {
  testWidgets('continuación vacía muestra carga, error y reintenta el cursor', (
    tester,
  ) async {
    final pendiente = Completer<PaginaNegocios>();
    var reintento = false;
    final fake = ListaServiceFalso()
      ..responder = (cursor) async {
        final numero = cursor == null ? 1 : int.parse(cursor);
        if (numero <= 5) return pagina([], '${numero + 1}');
        return reintento ? pagina([resumen('recuperado')]) : pendiente.future;
      };
    await tester.pumpWidget(
      MaterialApp(home: ListaNegociosPage(negociosService: fake)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(MensajesNegocios.cargarMas));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(MensajesNegocios.listaVacia), findsNothing);
    expect(fake.llamadas, [null, '2', '3', '4', '5', '6']);
    pendiente.completeError(const SocketException('sin conexión'));
    await tester.pumpAndSettle();
    expect(find.text(MensajesNegocios.errorRed), findsOneWidget);
    expect(find.text(MensajesNegocios.reintentar), findsOneWidget);
    expect(find.text(MensajesNegocios.listaVacia), findsNothing);
    reintento = true;
    await tester.tap(find.text(MensajesNegocios.reintentar));
    await tester.pumpAndSettle();
    expect(fake.llamadas, [null, '2', '3', '4', '5', '6', '6']);
    expect(find.text('Negocio recuperado'), findsOneWidget);
  });
}
