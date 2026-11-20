import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import 'fakes.dart';

void main() {
  testWidgets('lista y servicios conservan sus dobles y navegan al detalle', (
    tester,
  ) async {
    final lista = ListaServiceFalso()
      ..responder = (_) async => pagina([resumen('abc123')]);
    final detalle = DetalleServiceFalso();
    await tester.pumpWidget(
      MaterialApp(
        home: ListaNegociosPage(negociosService: lista),
        onGenerateRoute: (ruta) => MaterialPageRoute<void>(
          settings: ruta,
          builder: (_) => PerfilNegocioPage(
            negocioId: ruta.name!.split('/').last,
            negociosService: detalle,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Negocio abc123'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Z Corte'));
    await tester.tap(find.text('Z Corte'));
    await tester.pumpAndSettle();
    expect(find.text('Lavado y corte de cabello'), findsOneWidget);
    expect(lista.llamadas, [null]);
    expect(detalle.consultasServicios, 1);
    expect(detalle.consultasDetalle, 1);
    expect(detalle.negocioConsultado, 'abc123');
    expect(detalle.servicioConsultado, 's2');
  });
}
