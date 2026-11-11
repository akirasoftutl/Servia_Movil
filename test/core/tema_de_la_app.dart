import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/main.dart';

/// Tema que usa la app de verdad (el de ServiaApp, no una copia). Requiere
/// un `SizedBox` montado como raíz (sin MaterialApp, para que el MaterialApp
/// con el tema se monte nuevo y no anime la transición desde el de Flutter).
ThemeData temaDeLaApp(WidgetTester tester) {
  final contexto = tester.element(find.byType(SizedBox).first);
  return (const ServiaApp().build(contexto) as MaterialApp).theme!;
}
