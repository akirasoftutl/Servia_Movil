import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/ayuda/pages/reportar_problema_page.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tokens.dart';

import '../../core/tema_de_la_app.dart';
import '../reservas/fakes.dart';
import 'fakes_ayuda.dart';

void main() {
  test('el código de Ayuda no usa colores ni tipografías literales', () {
    final archivos = Directory('lib/features/ayuda')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(archivos, isNotEmpty);
    final prohibido = RegExp(
      r'Color\(0x|Colors\.|fontSize:|fontWeight:|fontFamily:|BorderRadius\.circular|EdgeInsets\.(all|symmetric|only|fromLTRB)\([^)]*\b[0-9]+(\.[0-9]+)?\b(?!\s*[,)]*\s*\n?\s*Espacios)',
    );
    for (final archivo in archivos) {
      final texto = archivo.readAsStringSync();
      // 0 no cuenta como espacio literal.
      final sinCeros = texto.replaceAll(RegExp(r'\b0,'), 'CERO,');
      expect(
        prohibido.hasMatch(sinCeros),
        isFalse,
        reason: '${archivo.path} usa valores literales en vez del tema',
      );
    }
  });

  testWidgets('botón, campos y tarjetas toman su estilo de TemaServia', (
    tester,
  ) async {
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
    // Botón principal: 52 dp de alto y color primario del tema.
    expect(tester.getSize(boton).height, Medidas.boton);
    final material = tester.widget<Material>(
      find.descendant(of: boton, matching: find.byType(Material)).first,
    );
    expect(material.color, ColoresServia.primario);

    // Los campos usan el borde redondeado del tema.
    final decorador = tester.widget<InputDecorator>(
      find.descendant(
        of: find.byKey(const Key('campo-asunto')),
        matching: find.byType(InputDecorator),
      ),
    );
    expect(decorador.decoration.helperText, isNotNull);
    final borde = tema.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    expect(borde.borderRadius, Radios.campo);

    // La tarjeta del reporte es la del tema.
    final tarjeta = tester.widget<Card>(find.byType(Card).first);
    expect(tarjeta.color, isNull);
    expect(tarjeta.shape, isNull);

    // Mismo margen lateral que el resto de pantallas de formulario.
    expect(tester.getTopLeft(boton).dx, Espacios.l);
  });
}
