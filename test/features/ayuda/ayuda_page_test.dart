import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/ayuda/pages/ayuda_page.dart';
import 'package:servia/features/ayuda/pages/reportar_problema_page.dart';

import '../reservas/fakes.dart';
import 'fakes_ayuda.dart';

Future<void> abrir(WidgetTester tester, {SoporteFalso? soporte}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AyudaPage(
        authService: SesionFalsa(),
        soporteService: soporte ?? SoporteFalso(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const preguntas = {
    '¿Cómo reservo un servicio?': 'Elige un negocio',
    '¿Mi reserva se confirma sola?': 'Pendiente',
    '¿Cuánto tarda el negocio en responder?': '2 horas',
    '¿Mi horario queda apartado mientras espero?': 'ocupa el horario',
    '¿Puedo cancelar?': '24 horas',
    '¿Cómo cambio mis datos o mi contraseña?': 'Mi perfil',
    'Algo no funciona': 'Reportar un problema',
  };

  testWidgets('muestra el título y las preguntas frecuentes, plegadas', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.widgetWithText(AppBar, 'Ayuda'), findsOneWidget);
    expect(find.text('Preguntas frecuentes'), findsOneWidget);
    for (final pregunta in preguntas.keys) {
      await tester.scrollUntilVisible(find.text(pregunta), 200);
      expect(find.text(pregunta), findsOneWidget);
    }
    // Plegadas: ninguna respuesta se ve todavía.
    expect(find.textContaining('Elige un negocio'), findsNothing);
    expect(find.textContaining('24 horas'), findsNothing);
  });

  testWidgets('al tocar una pregunta se despliega su respuesta y se pliega', (
    tester,
  ) async {
    await abrir(tester);
    for (final MapEntry(:key, :value) in preguntas.entries) {
      if (key == 'Algo no funciona') continue;
      final pregunta = find.text(key);
      await tester.scrollUntilVisible(pregunta, 200);
      await tester.tap(pregunta);
      await tester.pumpAndSettle();
      expect(find.textContaining(value), findsWidgets, reason: key);
      await tester.tap(pregunta);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('las respuestas siguen lo decidido: 2 h, D2, D4', (tester) async {
    await abrir(tester);
    Future<String> respuesta(String pregunta) async {
      await tester.scrollUntilVisible(find.text(pregunta), 200);
      await tester.tap(find.text(pregunta));
      await tester.pumpAndSettle();
      final texto = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '');
      return texto.join(' | ');
    }

    expect(
      await respuesta('¿Cuánto tarda el negocio en responder?'),
      contains('hasta 2 horas o hasta la hora de la cita'),
    );
    expect(
      await respuesta('¿Puedo cancelar?'),
      allOf(
        contains('Pendiente'),
        contains('Confirmada'),
        contains('24 horas'),
      ),
    );
  });

  testWidgets('el botón «Reportar un problema» abre el formulario', (
    tester,
  ) async {
    final soporte = SoporteFalso();
    await abrir(tester, soporte: soporte);
    final boton = find.widgetWithText(FilledButton, 'Reportar un problema');
    await tester.scrollUntilVisible(boton, 200);
    await tester.tap(boton);
    await tester.pumpAndSettle();
    expect(find.byType(ReportarProblemaPage), findsOneWidget);
    expect(find.text('Asunto'), findsOneWidget);
    // La pantalla abierta usa el mismo servicio: carga la lista de la cuenta.
    expect(soporte.listados, 1);
  });

  testWidgets('«Algo no funciona» también lleva al formulario', (tester) async {
    await abrir(tester);
    final pregunta = find.text('Algo no funciona');
    await tester.scrollUntilVisible(pregunta, 200);
    await tester.tap(pregunta);
    await tester.pumpAndSettle();
    final enlace = find.widgetWithText(OutlinedButton, 'Reportar un problema');
    expect(enlace, findsOneWidget);
    await tester.ensureVisible(enlace);
    await tester.tap(enlace);
    await tester.pumpAndSettle();
    expect(find.byType(ReportarProblemaPage), findsOneWidget);
  });

  testWidgets('no promete cosas fuera del MVP ni inventa contactos', (
    tester,
  ) async {
    await abrir(tester);
    for (final pregunta in preguntas.keys) {
      await tester.scrollUntilVisible(find.text(pregunta), 200);
      await tester.tap(find.text(pregunta));
      await tester.pumpAndSettle();
    }
    final todo = tester
        .widgetList<Text>(find.byType(Text, skipOffstage: false))
        .map((t) => t.data ?? '')
        .join(' ')
        .toLowerCase();
    for (final prohibida in ['reseña', 'mensaje', 'mapa', '@', 'whatsapp']) {
      expect(todo, isNot(contains(prohibida)), reason: prohibida);
    }
  });
}
