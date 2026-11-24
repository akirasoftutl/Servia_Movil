import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/favoritos/data/favoritos_controlador.dart';
import 'package:servia/features/favoritos/mensajes.dart';
import 'package:servia/features/favoritos/pages/boton_favorito.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import '../negocios/fakes.dart';
import 'fakes_favoritos.dart';

Future<void> abrirPerfil(
  WidgetTester tester,
  FavoritosControlador controlador,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilNegocioPage(
        negocioId: 'abc123',
        negociosService: NegociosServiceFalso(),
        favoritos: controlador,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

IconButton boton(WidgetTester tester) => tester.widget<IconButton>(
  find.descendant(
    of: find.byType(BotonFavorito),
    matching: find.byType(IconButton),
  ),
);

void main() {
  late ApiFavoritosFalsa api;
  late SesionFavoritos sesion;
  late FavoritosControlador controlador;

  setUp(() {
    api = ApiFavoritosFalsa();
    sesion = SesionFavoritos('ana');
    controlador = api.controlador(sesion);
  });

  testWidgets('sin sesión el perfil no ofrece el corazón ni llama a la API', (
    tester,
  ) async {
    sesion.usuario = null;
    await abrirPerfil(tester, controlador);
    expect(find.byType(BotonFavorito), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(api.peticiones, isEmpty);
  });

  testWidgets(
    'al abrir consulta la lista: negocio no favorito, corazón vacío',
    (tester) async {
      await abrirPerfil(tester, controlador);
      expect(api.metodos(), ['GET /favoritos/negocios']);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byTooltip(MensajesFavoritos.agregar), findsOneWidget);
    },
  );

  testWidgets('si ya es favorito el corazón sale marcado y quita', (
    tester,
  ) async {
    api.de('ana').add(negocioFavorito('abc123'));
    await abrirPerfil(tester, controlador);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byTooltip(MensajesFavoritos.quitar), findsOneWidget);

    await tester.tap(find.byTooltip(MensajesFavoritos.quitar));
    await tester.pumpAndSettle();

    expect(api.metodos(), contains('DELETE /favoritos/negocios/abc123'));
    expect(api.de('ana'), isEmpty);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byTooltip(MensajesFavoritos.agregar), findsOneWidget);
  });

  testWidgets(
    'agregar: queda marcado al instante, se deshabilita y luego se habilita',
    (tester) async {
      await abrirPerfil(tester, controlador);
      api.retener = Completer<void>();

      await tester.tap(find.byTooltip(MensajesFavoritos.agregar));
      await tester.pump();

      // Optimista: ya está marcado aunque la API no ha respondido.
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(boton(tester).onPressed, isNull);

      api.retener!.complete();
      await tester.pumpAndSettle();

      expect(api.metodos(), contains('PUT /favoritos/negocios/abc123'));
      expect(api.de('ana').map((n) => n['id']), ['abc123']);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(boton(tester).onPressed, isNotNull);
      expect(find.byTooltip(MensajesFavoritos.quitar), findsOneWidget);
    },
  );

  testWidgets(
    '404: vuelve a su estado y dice que el negocio no está disponible',
    (tester) async {
      await abrirPerfil(tester, controlador);
      api.noDisponibles.add('abc123');

      await tester.tap(find.byTooltip(MensajesFavoritos.agregar));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text(MensajesNegocios.noDisponible), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(boton(tester).onPressed, isNotNull);
    },
  );

  testWidgets(
    '409: vuelve a su estado y muestra el mensaje de la API en español',
    (tester) async {
      await abrirPerfil(tester, controlador);
      api.tope = 0;

      await tester.tap(find.byTooltip(MensajesFavoritos.agregar));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(
        find.text(
          'Llegaste al máximo de 0 favoritos. Quita alguno para agregar otro.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('error de red: revierte y avisa sin diálogos', (tester) async {
    await abrirPerfil(tester, controlador);
    api.errores['PUT'] = (codigo: 500, mensaje: 'Falló');

    await tester.tap(find.byTooltip(MensajesFavoritos.agregar));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text(MensajesNegocios.errorApi), findsOneWidget);
  });

  testWidgets('401: revierte y pide iniciar sesión de nuevo', (tester) async {
    await abrirPerfil(tester, controlador);
    api.errores['PUT'] = (codigo: 401, mensaje: 'Unauthorized');

    await tester.tap(find.byTooltip(MensajesFavoritos.agregar));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text(MensajesFavoritos.sesionVencida), findsOneWidget);
  });

  testWidgets('si no se pudo consultar la lista, tocar el corazón reintenta', (
    tester,
  ) async {
    api.errores['GET'] = (codigo: 500, mensaje: 'Falló');
    await abrirPerfil(tester, controlador);
    expect(find.byTooltip(MensajesFavoritos.reintentarEstado), findsOneWidget);

    api.errores.clear();
    api.de('ana').add(negocioFavorito('abc123'));
    await tester.tap(find.byTooltip(MensajesFavoritos.reintentarEstado));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byTooltip(MensajesFavoritos.quitar), findsOneWidget);
  });

  testWidgets('el corazón tiene etiqueta accesible y área táctil de 48 dp', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await abrirPerfil(tester, controlador);

    final nodo = tester.getSemantics(
      find.descendant(
        of: find.byType(BotonFavorito),
        matching: find.byType(IconButton),
      ),
    );
    expect(nodo.tooltip, MensajesFavoritos.agregar);
    expect(nodo.getSemanticsData().hasFlag(SemanticsFlag.isButton), isTrue);
    final tamano = tester.getSize(
      find.descendant(
        of: find.byType(BotonFavorito),
        matching: find.byType(IconButton),
      ),
    );
    expect(tamano.width, greaterThanOrEqualTo(48));
    expect(tamano.height, greaterThanOrEqualTo(48));
    semantica.dispose();
  });
}
