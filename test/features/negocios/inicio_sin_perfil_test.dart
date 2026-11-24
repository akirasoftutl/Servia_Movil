import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/home/pages/home_page.dart';

import '../perfil/fakes_perfil.dart';
import 'fakes.dart';

void main() {
  testWidgets('inicio no requiere datos personales para mostrar negocios', (
    tester,
  ) async {
    // El selector de orden ocupa unos dp más en el encabezado: viewport más alto.
    tester.view.physicalSize = const Size(800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onCerrarSesion: () {},
          authService: SesionPerfilFalsa([])..usuario = null,
          negociosService: ListaServiceFalso()
            ..responder = (_) async => pagina([resumen('inicio')]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ubicación actual'), findsOneWidget);
    expect(find.text('Explorar todos los servicios'), findsOneWidget);
    expect(find.text('Negocio inicio'), findsWidgets);
    expect(find.text('Nombre privado'), findsNothing);
    expect(find.text('correo@privado'), findsNothing);
  });
}
