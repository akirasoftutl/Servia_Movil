import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';
import 'utilidades_prueba.dart';

void main() {
  for (final acepta in [true, false]) {
    testWidgets('perfil abre detalle y conserva aceptaReservas $acepta', (
      tester,
    ) async {
      final service = DetalleServiceFalso()..aceptaReservas = acepta;
      await abrirPerfil(tester, service);
      await tester.ensureVisible(find.text('Z Corte'));
      await tester.tap(find.text('Z Corte'));
      await tester.pumpAndSettle();
      expect(service.consultasServicios, 1);
      expect(service.negocioConsultado, 'abc123');
      expect(service.servicioConsultado, 's2');
      expect(find.text('Lavado y corte de cabello'), findsOneWidget);
      expect(find.text('Reservar'), acepta ? findsOneWidget : findsNothing);
    });
  }
}
