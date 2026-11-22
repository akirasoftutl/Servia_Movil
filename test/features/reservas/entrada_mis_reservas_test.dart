import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/reservas/pages/mis_reservas_page.dart';

import '../negocios/fakes.dart';
import 'fakes.dart';

void main() {
  testWidgets('desde el inicio se abre «Mis reservas» y se vuelve a la lista', (
    tester,
  ) async {
    final sesion = SesionFalsa();
    addTearDown(sesion.eventos.close);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onCerrarSesion: () {},
          negociosService: ListaServiceFalso()
            ..responder = (_) async => pagina([resumen('inicio')]),
          authService: sesion,
          reservasService: ReservasFalso(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Negocio inicio'), findsOneWidget);
    // La barra inferior nueva no usa tooltips: cada ítem tiene su etiqueta.
    expect(find.text('Actividad'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);

    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    expect(find.byType(MisReservasPage), findsOneWidget);
    expect(find.text('No tienes reservas próximas.'), findsOneWidget);

    // Es un IndexedStack: se vuelve tocando «Inicio», no con pageBack.
    await tester.tap(find.text('Inicio'));
    await tester.pumpAndSettle();
    expect(find.byType(MisReservasPage), findsNothing);
    expect(find.text('Negocio inicio'), findsOneWidget);
  });
}
