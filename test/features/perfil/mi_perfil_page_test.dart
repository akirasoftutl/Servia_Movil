import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/auth/mensajes.dart';
import 'package:servia/features/perfil/pages/mi_perfil_page.dart';

import 'fakes_perfil.dart';

Widget pagina(SesionPerfilFalsa sesion, PerfilClienteFalso api) => MaterialApp(
  home: MiPerfilPage(authService: sesion, perfilClienteService: api),
);

Finder campo(String etiqueta) => find.widgetWithText(TextFormField, etiqueta);

Future<void> abrir(
  WidgetTester tester,
  SesionPerfilFalsa sesion,
  PerfilClienteFalso api,
) async {
  await tester.pumpWidget(pagina(sesion, api));
  await tester.pumpAndSettle();
}

Future<void> editar(WidgetTester tester) async {
  await tester.tap(find.text('Editar'));
  await tester.pumpAndSettle();
}

Future<void> guardar(WidgetTester tester) async {
  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();
}

void main() {
  late List<String> eventos;
  late SesionPerfilFalsa sesion;

  setUp(() {
    eventos = [];
    sesion = SesionPerfilFalsa(eventos);
  });

  testWidgets('C1: el cliente ve su nombre, correo y teléfono (GET)', (
    tester,
  ) async {
    final api = PerfilClienteFalso(eventos);
    await abrir(tester, sesion, api);
    expect(find.text('Ana Pérez'), findsOneWidget);
    expect(find.text('ana@test.com'), findsOneWidget);
    expect(find.text('4771234567'), findsOneWidget);
    expect(eventos, ['token', 'GET']);
  });

  testWidgets(
    'C2: edita nombre y teléfono, ve el aviso y al reabrir salen los nuevos',
    (tester) async {
      final api = PerfilClienteFalso(eventos);
      await abrir(tester, sesion, api);
      await editar(tester);
      await tester.enterText(campo('Nombre completo'), 'Ana Ruiz');
      await tester.enterText(campo('Teléfono (10 dígitos)'), '4770000000');
      await guardar(tester);

      expect(api.ultimoPatch, {
        'nombre': 'Ana Ruiz',
        'telefono': '4770000000',
        'correo': null,
      });
      expect(find.text('Tus datos se guardaron.'), findsOneWidget);
      expect(find.text('Ana Ruiz'), findsOneWidget);
      expect(find.text('4770000000'), findsOneWidget);
      // Solo cambió nombre y teléfono: no hace falta renovar el token.
      expect(eventos.contains('token-nuevo'), isFalse);

      // Reabrir la pantalla: los datos salen de la API.
      await tester.pumpWidget(const SizedBox());
      await abrir(tester, sesion, api);
      expect(find.text('Ana Ruiz'), findsOneWidget);
      expect(find.text('4770000000'), findsOneWidget);
    },
  );

  testWidgets(
    'C3: correo de otra cuenta (409) → aviso junto al correo y no cambia (RN-02)',
    (tester) async {
      final api = PerfilClienteFalso(
        eventos,
        correosOcupados: {'otra@test.com'},
      );
      await abrir(tester, sesion, api);
      await editar(tester);
      await tester.enterText(campo('Correo'), 'otra@test.com');
      await guardar(tester);

      expect(
        find.descendant(
          of: campo('Correo'),
          matching: find.text('Ese correo ya está en uso.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tus datos se guardaron.'), findsNothing);
      expect(eventos.contains('token-nuevo'), isFalse);
      expect(api.guardado.correo, 'ana@test.com');
      // El botón queda activo para corregir.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
            .onPressed,
        isNotNull,
      );

      // Al corregir el correo, el aviso desaparece.
      await tester.enterText(campo('Correo'), 'otra2@test.com');
      await tester.pump();
      expect(find.text('Ese correo ya está en uso.'), findsNothing);

      // Cancelar: el perfil sigue con el correo de antes.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('ana@test.com'), findsOneWidget);
    },
  );

  testWidgets('correo libre: guarda y renueva el token con getIdToken(true)', (
    tester,
  ) async {
    final api = PerfilClienteFalso(eventos);
    await abrir(tester, sesion, api);
    await editar(tester);
    await tester.enterText(campo('Correo'), 'nuevo@test.com');
    await guardar(tester);

    expect(api.ultimoPatch['correo'], 'nuevo@test.com');
    expect(find.text('Tus datos se guardaron.'), findsOneWidget);
    expect(find.text('nuevo@test.com'), findsOneWidget);
    // Primero guarda en la API y después renueva el token.
    expect(eventos, ['token', 'GET', 'token', 'PATCH', 'token-nuevo']);
  });

  testWidgets(
    'validaciones del registro: errores junto a cada campo, sin llamar a la API',
    (tester) async {
      final api = PerfilClienteFalso(eventos);
      await abrir(tester, sesion, api);
      await editar(tester);
      await tester.enterText(campo('Nombre completo'), 'A');
      await tester.enterText(campo('Correo'), 'sin-arroba');
      await tester.enterText(campo('Teléfono (10 dígitos)'), '123456789');
      await guardar(tester);

      for (final (etiqueta, texto) in [
        ('Nombre completo', 'El nombre debe tener al menos 2 caracteres.'),
        ('Correo', 'El correo debe tener un formato válido.'),
        (
          'Teléfono (10 dígitos)',
          'El teléfono debe contener exactamente 10 dígitos numéricos.',
        ),
      ]) {
        expect(
          find.descendant(of: campo(etiqueta), matching: find.text(texto)),
          findsOneWidget,
        );
      }
      expect(api.actualizaciones, 0);
    },
  );

  testWidgets(
    'falla de red al guardar: mensaje genérico y no se queda cargando',
    (tester) async {
      final api = PerfilClienteFalso(
        eventos,
        errorAlGuardar: TimeoutException('red'),
      );
      await abrir(tester, sesion, api);
      await editar(tester);
      await tester.enterText(campo('Nombre completo'), 'Ana Ruiz');
      await guardar(tester);

      expect(find.text(MensajesAuth.errorRed), findsOneWidget);
      expect(find.text('Tus datos se guardaron.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar'))
            .onPressed,
        isNotNull,
      );
      expect(api.guardado.nombre, 'Ana Pérez');
    },
  );

  testWidgets('sin cambios: Guardar no llama a la API', (tester) async {
    final api = PerfilClienteFalso(eventos);
    await abrir(tester, sesion, api);
    await editar(tester);
    await guardar(tester);
    expect(api.actualizaciones, 0);
    expect(find.text('Editar'), findsOneWidget);
  });

  testWidgets(
    'error de la API al cargar: muestra el motivo y permite reintentar',
    (tester) async {
      final api = PerfilClienteFalso(
        eventos,
        error: ApiException(403, 'Tu cuenta está desactivada.'),
      );
      await abrir(tester, sesion, api);
      expect(find.text('Tu cuenta está desactivada.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
    },
  );

  testWidgets('red al cargar: mensaje genérico de la app', (tester) async {
    final api = PerfilClienteFalso(eventos, error: TimeoutException('red'));
    await abrir(tester, sesion, api);
    expect(find.text(MensajesAuth.errorRed), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('sin sesión no consulta la API', (tester) async {
    sesion.usuario = null;
    final api = PerfilClienteFalso(eventos);
    await abrir(tester, sesion, api);
    expect(eventos, isEmpty);
    expect(find.text('Editar'), findsNothing);
  });
}
