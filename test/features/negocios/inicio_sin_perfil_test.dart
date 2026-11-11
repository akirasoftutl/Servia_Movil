import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/home/pages/home_page.dart';

import 'fakes.dart';

void main() {
  testWidgets('inicio no requiere datos personales para mostrar negocios', (
    tester,
  ) async {
    var cierres = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onCerrarSesion: () => cierres++,
          negociosService: ListaServiceFalso()
            ..responder = (_) async => pagina([resumen('inicio')]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Negocio inicio'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar sesión'));
    expect(cierres, 1);
  });
}
