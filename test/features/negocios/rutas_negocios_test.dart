import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/main.dart';
import 'package:servia/features/auth/pages/auth_gate.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';
import 'package:servia/features/negocios/rutas_negocios.dart';

void main() {
  testWidgets('la ruta válida crea el perfil con el id exacto', (tester) async {
    final ajustes = const RouteSettings(name: '/negocios/abc123');
    final ruta = generarRutaNegocios(ajustes) as MaterialPageRoute;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final contexto = tester.element(find.byType(SizedBox).first);
    final perfil = ruta.builder(contexto) as PerfilNegocioPage;
    expect(perfil.negocioId, 'abc123');
    expect(ruta.settings, ajustes);
  });
  test('rutas vacías o con segmentos extra o codificados devuelven null', () {
    for (final ruta in [
      '/negocios/',
      '/negocios/a/b',
      '/negocios/a%2Fb',
      '/otra',
      '/negocios/a?b',
      '/negocios/${'a' * 129}',
    ]) {
      expect(
        generarRutaNegocios(RouteSettings(name: ruta)),
        isNull,
        reason: ruta,
      );
    }
    expect(generarRutaNegocios(const RouteSettings()), isNull);
  });
  testWidgets('la app conserva home y conecta ambas fábricas de rutas', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final contexto = tester.element(find.byType(SizedBox).first);
    final app = const ServiaApp().build(contexto) as MaterialApp;
    expect(app.home, isA<AuthGate>());
    expect(app.onGenerateRoute, generarRutaNegocios);
    expect(app.onUnknownRoute, generarRutaNoDisponible);
  });
  testWidgets('ruta desconocida muestra no disponible y permite volver', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (contexto) => TextButton(
            onPressed: () => Navigator.pushNamed(contexto, '/negocios/a/b'),
            child: const Text('Abrir'),
          ),
        ),
        onGenerateRoute: generarRutaNegocios,
        onUnknownRoute: generarRutaNoDisponible,
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text(MensajesNegocios.noDisponible), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
  });
}
