import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tema_servia.dart';
import 'package:servia/core/theme/tokens.dart';

import 'tema_de_la_app.dart';

double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (claro, oscuro) = la > lb ? (la, lb) : (lb, la);
  return (claro + 0.05) / (oscuro + 0.05);
}

void main() {
  testWidgets('ServiaApp usa el tema de Servia y no el de ejemplo', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final tema = temaDeLaApp(tester);
    final ejemplo = ColorScheme.fromSeed(seedColor: Colors.deepPurple);

    expect(tema.useMaterial3, isTrue);
    expect(tema.colorScheme.primary, ColoresServia.primario);
    expect(tema.colorScheme.primary, isNot(ejemplo.primary));
    expect(tema.scaffoldBackgroundColor, ColoresServia.fondo);
    expect(tema.textTheme.bodyMedium?.fontFamily, 'PlusJakartaSans');
    expect(tema.extension<ColoresSemanticos>(), isNotNull);
  });

  testWidgets('un botón y un campo toman el color y la forma del tema', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final tema = temaDeLaApp(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: tema,
        home: Scaffold(
          body: Column(
            children: [
              FilledButton(onPressed: () {}, child: const Text('Relleno')),
              ElevatedButton(onPressed: () {}, child: const Text('Elevado')),
              TextButton(onPressed: () {}, child: const Text('Texto')),
              const TextField(decoration: InputDecoration(hintText: 'Campo')),
            ],
          ),
        ),
      ),
    );

    for (final (tipo, texto) in [
      (FilledButton, 'Relleno'),
      (ElevatedButton, 'Elevado'),
    ]) {
      final material = tester.widget<Material>(
        find.descendant(
          of: find.widgetWithText(tipo, texto),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, ColoresServia.primario, reason: '$tipo');
      final forma = material.shape! as RoundedRectangleBorder;
      expect(forma.borderRadius, Radios.campo, reason: '$tipo');
      expect(
        tester.getSize(find.widgetWithText(tipo, texto)).height,
        greaterThanOrEqualTo(Medidas.boton),
        reason: '$tipo',
      );
    }
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Texto')).height,
      greaterThanOrEqualTo(Medidas.tactil),
    );

    final campo = tester.widget<InputDecorator>(find.byType(InputDecorator));
    final borde = campo.decoration.enabledBorder! as OutlineInputBorder;
    expect(borde.borderRadius, Radios.campo);
    expect(borde.borderSide.color, ColoresServia.bordeCampo);
    final foco = campo.decoration.focusedBorder! as OutlineInputBorder;
    expect(foco.borderSide.color, ColoresServia.primario);
    expect(campo.decoration.filled, isTrue);
  });

  group('contraste AA de la paleta', () {
    const c = ColoresServia.esquema;
    final textos = <String, (Color, Color, double)>{
      'texto del botón sobre primario': (c.onPrimary, c.primary, 4.5),
      'enlace primario sobre superficie': (c.primary, c.surface, 4.5),
      'enlace primario sobre fondo': (c.primary, ColoresServia.fondo, 4.5),
      'texto sobre superficie': (c.onSurface, c.surface, 4.5),
      'texto sobre fondo': (c.onSurface, ColoresServia.fondo, 4.5),
      'texto suave sobre superficie': (c.onSurfaceVariant, c.surface, 4.5),
      'texto suave sobre fondo': (c.onSurfaceVariant, ColoresServia.fondo, 4.5),
      'texto suave sobre superficie hundida': (
        c.onSurfaceVariant,
        c.surfaceContainerHigh,
        4.5,
      ),
      'aviso informativo': (c.onPrimaryContainer, c.primaryContainer, 4.5),
      'error sobre su fondo': (c.onErrorContainer, c.errorContainer, 4.5),
      'error sobre superficie': (c.error, c.surface, 4.5),
      'éxito sobre su fondo': (
        ColoresServia.exito,
        ColoresServia.exitoFondo,
        4.5,
      ),
      'advertencia sobre su fondo': (
        ColoresServia.aviso,
        ColoresServia.avisoFondo,
        4.5,
      ),
      'aviso flotante': (c.onInverseSurface, c.inverseSurface, 4.5),
      'borde de campo (no texto)': (c.outline, c.surface, 3),
      'indicador de carga sobre fondo (no texto)': (
        temaServia().progressIndicatorTheme.color!,
        ColoresServia.fondo,
        3,
      ),
      'borde de campo sobre fondo (no texto)': (
        c.outline,
        ColoresServia.fondo,
        3,
      ),
    };
    for (final MapEntry(key: nombre, value: (frente, fondo, minimo))
        in textos.entries) {
      test(nombre, () {
        expect(contraste(frente, fondo), greaterThanOrEqualTo(minimo));
      });
    }

    test('el naranja de marca no se usa para texto sobre blanco', () {
      // Documenta por qué existe el primario: #E27441 no llega a 4.5:1.
      expect(contraste(Colors.white, ColoresServia.marca), lessThan(4.5));
      expect(c.primary, isNot(ColoresServia.marca));
    });
  });
}
