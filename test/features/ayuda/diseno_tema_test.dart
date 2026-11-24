import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/ayuda/pages/reportar_problema_page.dart';
import 'package:servia/core/theme/tokens.dart';

import '../../core/tema_de_la_app.dart';
import '../reservas/fakes.dart';
import 'fakes_ayuda.dart';

void main() {
  test('el código de Ayuda se queda en la paleta neutra del rediseño', () {
    final archivos = Directory('lib/features/ayuda')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(archivos, isNotEmpty);
    // El rediseño sustituye la paleta naranja por grises y blanco, con el
    // negro de los botones y un par de acentos para errores y avisos.
    const permitidos = {
      '0xFF111827',
      '0xFFF3F4F6',
      '0xFF6B7280',
      '0xFF0F0F0F',
      '0xFFE5E7EB',
      '0xFFF9FAFB',
      '0xFF4B5563',
      '0xFFD1D5DB',
      '0xFFB91C1C',
      '0xFF9CA3AF',
      '0xFFFEF3C7',
      '0xFFB45309',
    };
    final literal = RegExp(r'Color\((0x[0-9A-Fa-f]{8})\)');
    for (final archivo in archivos) {
      for (final coincidencia in literal.allMatches(
        archivo.readAsStringSync(),
      )) {
        final color = coincidencia.group(1)!;
        expect(
          permitidos,
          contains(color),
          reason: '$archivo introduce $color fuera de la paleta de Ayuda',
        );
      }
    }
  });

  testWidgets('botón, campos y tarjetas siguen el diseño de Ayuda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    final tema = temaDeLaApp(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: tema,
        home: ReportarProblemaPage(
          authService: SesionFalsa(),
          soporteService: SoporteFalso(existentes: [reporte('Uno')]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boton = find.byKey(const Key('boton-enviar-reporte'));
    // Botón principal negro: 52 dp de alto.
    expect(tester.getSize(boton).height, Medidas.boton);
    final material = tester.widget<Material>(
      find.descendant(of: boton, matching: find.byType(Material)).first,
    );
    expect(material.color, const Color(0xFF0F0F0F));

    // Los campos conservan la ayuda y el borde gris redondeado del formulario.
    final decorador = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('campo-asunto')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(decorador.decoration.helperText, isNotNull);
    final borde = decorador.decoration.enabledBorder as OutlineInputBorder;
    expect(borde.borderRadius, BorderRadius.circular(14));
    expect(borde.borderSide.color, const Color(0xFFE5E7EB));

    // La tarjeta del reporte es blanca con borde suave y esquinas redondeadas.
    final tarjeta = tester.widget<Container>(
      find
          .ancestor(of: find.text('Uno'), matching: find.byType(Container))
          .first,
    );
    final caja = tarjeta.decoration! as BoxDecoration;
    expect(caja.color, Colors.white);
    expect(caja.borderRadius, BorderRadius.circular(18));
    expect((caja.border! as Border).top.color, const Color(0xFFE5E7EB));

    // El botón queda dentro de la tarjeta, por lo menos con el margen
    // lateral habitual del resto de pantallas.
    expect(tester.getTopLeft(boton).dx, greaterThanOrEqualTo(Espacios.l));
  });
}
