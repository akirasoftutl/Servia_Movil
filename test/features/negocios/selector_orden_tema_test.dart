import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/features/negocios/data/orden_negocios.dart';
import 'package:servia/features/negocios/pages/selector_orden_negocios.dart';

import '../../core/tema_de_la_app.dart';

BoxDecoration _caja(WidgetTester tester) =>
    tester
            .widget<Container>(
              find
                  .descendant(
                    of: find.byType(SelectorOrdenNegocios),
                    matching: find.byType(Container),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

Future<void> _montar(WidgetTester tester, ThemeData tema) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: tema,
      home: Scaffold(
        body: SelectorOrdenNegocios(
          orden: OrdenNegocios.nombre,
          onOrden: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('colores, radio y tipografía vienen del tema de Servia', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final tema = temaDeLaApp(tester);
    await _montar(tester, tema);
    final caja = _caja(tester);
    expect(caja.color, ColoresServia.superficie);
    expect((caja.border! as Border).top.color, ColoresServia.bordeCampo);
    expect(caja.borderRadius, BorderRadius.circular(Medidas.tactil / 2));
    final texto = tester.widget<DefaultTextStyle>(
      find
          .descendant(
            of: find.byType(DropdownButton<OrdenNegocios>),
            matching: find.byType(DefaultTextStyle),
          )
          .first,
    );
    expect(texto.style.fontFamily, tema.textTheme.bodyLarge!.fontFamily);
    expect(texto.style.color, tema.colorScheme.onSurface);
    expect(
      tester.getSize(find.byType(DropdownButton<OrdenNegocios>)).height,
      greaterThanOrEqualTo(Medidas.tactil),
    );
  });

  testWidgets('sin literales: cambiar el esquema del tema cambia el selector', (
    tester,
  ) async {
    const otro = ColorScheme.light(
      surface: Color(0xFF102030),
      outline: Color(0xFF405060),
    );
    await _montar(tester, ThemeData(colorScheme: otro));
    final caja = _caja(tester);
    expect(caja.color, otro.surface);
    expect((caja.border! as Border).top.color, otro.outline);
  });
}
