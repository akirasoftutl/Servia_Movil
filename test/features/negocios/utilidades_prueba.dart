import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import 'fakes.dart';

Future<void> abrirPerfil(
  WidgetTester tester,
  ServiciosServiceFalso servicio,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilNegocioPage(negocioId: 'abc123', negociosService: servicio),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> verServicios(WidgetTester tester) async {
  await tester.ensureVisible(find.text(MensajesNegocios.servicios));
  await tester.pumpAndSettle();
}

/// Lista vertical principal: los carruseles de la portada son horizontales.
Finder listaVertical() => find.byWidgetPredicate(
  (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
);

/// Lleva la lista principal al final para disparar la paginación por scroll.
Future<void> desplazarListaAlFinal(WidgetTester tester) async {
  final controller = tester.widget<ListView>(listaVertical()).controller!;
  controller.jumpTo(controller.position.maxScrollExtent);
  await tester.pump();
}

/// El selector de categorías es ahora una cuadrícula de opciones (con «Todo»).
Future<void> elegirCategoria(WidgetTester tester, String nombre) async {
  await tester.tap(
    find.descendant(
      of: find.byType(GridView),
      matching: find.text(nombre),
    ),
  );
  await tester.pumpAndSettle();
}

/// El botón de limpiar es un IconButton dentro de la barra de búsqueda.
Future<void> limpiarBusqueda(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.close_rounded));
  await tester.pumpAndSettle();
}
