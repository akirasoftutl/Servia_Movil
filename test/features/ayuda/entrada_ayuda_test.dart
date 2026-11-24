import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/ayuda/pages/ayuda_page.dart';
import 'package:servia/features/home/pages/home_page.dart';

import '../negocios/fakes.dart';
import '../reservas/fakes.dart';
import 'fakes_ayuda.dart';

Widget inicio({required bool conSesion, SoporteFalso? soporte}) => MaterialApp(
  home: HomePage(
    onCerrarSesion: () {},
    negociosService: ListaServiceFalso()
      ..responder = (_) async => pagina([resumen('inicio')]),
    authService: SesionFalsa(conSesion: conSesion),
    soporteService: soporte ?? SoporteFalso(),
  ),
);

void main() {
  testWidgets(
    'el inicio del cliente tiene el ícono «Ayuda» que abre la pantalla',
    (tester) async {
      await tester.pumpWidget(inicio(conSesion: true));
      await tester.pumpAndSettle();
      final icono = find.byTooltip('Ayuda');
      expect(icono, findsOneWidget);
      expect(
        find.descendant(of: icono, matching: find.byIcon(Icons.help_outline)),
        findsOneWidget,
      );

      await tester.tap(icono);
      await tester.pumpAndSettle();
      expect(find.byType(AyudaPage), findsOneWidget);
      expect(find.text('Preguntas frecuentes'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AyudaPage), findsNothing);
      expect(find.text('Negocio inicio'), findsOneWidget);
    },
  );

  testWidgets('sin sesión no se ofrece (reportar exige cuenta)', (
    tester,
  ) async {
    await tester.pumpWidget(inicio(conSesion: false));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Ayuda'), findsNothing);
  });
}
