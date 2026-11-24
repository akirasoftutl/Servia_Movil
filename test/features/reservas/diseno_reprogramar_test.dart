import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/features/reservas/data/detalle_reserva.dart';
import 'package:servia/features/reservas/pages/reprogramar_reserva_page.dart';

import '../../core/tema_de_la_app.dart';
import 'escenario_reprogramar.dart';

/// Archivos nuevos de la issue #80: sin valores literales de diseño.
const _archivosNuevos = [
  'lib/features/reservas/pages/reprogramar_reserva_page.dart',
  'lib/features/reservas/pages/resumen_cambio_reserva.dart',
  'lib/features/reservas/pages/lista_servicios_cambio.dart',
];

void main() {
  test('el código nuevo no usa colores, tamaños ni radios literales', () {
    final prohibido = RegExp(
      r'Color\(0x|Colors\.|fontSize:|fontWeight:|fontFamily:|BorderRadius\.circular|EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*\b[1-9][0-9]*(\.[0-9]+)?\b(?!\s*[,)]*\s*\n?\s*Espacios)|SizedBox\((width|height): *[1-9]',
    );
    for (final ruta in _archivosNuevos) {
      final archivo = File(ruta);
      expect(archivo.existsSync(), isTrue, reason: '$ruta no existe');
      expect(
        prohibido.hasMatch(archivo.readAsStringSync()),
        isFalse,
        reason: '$ruta usa valores literales en vez del tema',
      );
    }
  });

  testWidgets('botones, tarjetas y avisos toman su estilo de TemaServia', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    final tema = temaDeLaApp(tester);
    final e = EscenarioReprogramar();
    addTearDown(e.sesion.eventos.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: tema,
        home: ReprogramarReservaPage(
          reserva: DetalleReserva.fromJson(detalleApi()),
          authService: e.sesion,
          reservasService: e.reservas,
          negociosService: e.negocios,
          disponibilidadService: e.disponibilidad,
          ahora: () => ahoraReprogramar,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Botón principal: 52 dp y color primario del tema.
    final boton = find.byKey(const ValueKey('elegir-horario'));
    expect(tester.getSize(boton).height, Medidas.boton);
    final material = tester.widget<Material>(
      find.descendant(of: boton, matching: find.byType(Material)).first,
    );
    expect(material.color, ColoresServia.primario);
    final forma = material.shape! as RoundedRectangleBorder;
    expect(forma.borderRadius, Radios.campo);

    // La tarjeta de la cita es la del tema (radio y borde).
    final tarjeta = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const ValueKey('tarjeta-cita-actual')),
            matching: find.byType(Material),
          )
          .first,
    );
    final borde = tarjeta.shape! as RoundedRectangleBorder;
    expect(tarjeta.color, ColoresServia.superficie);
    expect(borde.borderRadius, Radios.tarjeta);
    expect(borde.side.color, ColoresServia.borde);

    // El fondo y el título salen del tema.
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      isNull,
    );
    final titulo = tester.widget<Text>(find.text('Cambiar tu reserva'));
    expect(titulo.style, isNull);
    expect(
      DefaultTextStyle.of(tester.element(find.text('Cambiar tu reserva')))
          .style
          .fontFamily,
      'PlusJakartaSans',
    );
  });
}
