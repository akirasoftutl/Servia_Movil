import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/data/negocio.dart';
import 'package:servia/features/negocios/data/servicio.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import 'fakes.dart';

/// El listado abre el perfil con su propia instancia del servicio, así que
/// delegamos las consultas del perfil al doble que queremos observar.
class ListaConDetalleFalso extends ListaServiceFalso {
  ListaConDetalleFalso(this.detalle);
  final DetalleServiceFalso detalle;

  @override
  Future<List<Servicio>> obtenerServicios(String negocioId) =>
      detalle.obtenerServicios(negocioId);

  @override
  Future<Negocio> obtenerNegocio(String id) => detalle.obtenerNegocio(id);

  @override
  Future<Servicio> obtenerServicio(String negocioId, String servicioId) =>
      detalle.obtenerServicio(negocioId, servicioId);
}

void main() {
  testWidgets('lista y servicios conservan sus dobles y navegan al detalle', (
    tester,
  ) async {
    final detalle = DetalleServiceFalso();
    final lista = ListaConDetalleFalso(detalle)
      ..responder = (_) async => pagina([resumen('abc123')]);
    await tester.pumpWidget(
      MaterialApp(home: ListaNegociosPage(negociosService: lista)),
    );
    await tester.pumpAndSettle();
    final tarjeta = find.text('Negocio abc123').first;
    await tester.ensureVisible(tarjeta);
    await tester.pumpAndSettle();
    await tester.tap(tarjeta);
    await tester.pumpAndSettle();
    expect(find.byType(PerfilNegocioPage), findsOneWidget);
    expect(find.text('Z Corte', skipOffstage: false), findsOneWidget);
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
