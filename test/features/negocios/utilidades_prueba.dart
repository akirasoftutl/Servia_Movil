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
