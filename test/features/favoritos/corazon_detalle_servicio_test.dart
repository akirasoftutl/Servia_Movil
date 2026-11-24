import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/features/favoritos/data/favoritos_servicios_controlador.dart';
import 'package:servia/features/favoritos/mensajes.dart';
import 'package:servia/features/favoritos/pages/boton_favorito_servicio.dart';
import 'package:servia/features/negocios/pages/detalle_servicio_page.dart';

import '../negocios/fakes.dart';
import 'fakes_favoritos.dart';

// El detalle de prueba es el servicio s2 del negocio abc123 (Z Corte, $150.50).
Future<void> abrirDetalle(
  WidgetTester tester,
  FavoritosServiciosControlador controlador,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DetalleServicioPage(
        negocioId: 'abc123',
        servicioId: 's2',
        aceptaReservas: true,
        negocioNombre: 'Salón Aurora',
        negociosService: DetalleServiceFalso(),
        favoritos: controlador,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _boton => find.descendant(
  of: find.byType(BotonFavoritoServicio),
  matching: find.byType(IconButton),
);

IconButton boton(WidgetTester tester) => tester.widget<IconButton>(_boton);

void main() {
  late ApiFavoritosFalsa api;
  late SesionFavoritos sesion;
  late FavoritosServiciosControlador controlador;

  setUp(() {
    api = ApiFavoritosFalsa();
    sesion = SesionFavoritos('ana');
    controlador = api.controladorServicios(sesion);
  });

  testWidgets('sin sesión no hay corazón ni se llama a la API', (tester) async {
    sesion.usuario = null;
    await abrirDetalle(tester, controlador);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(api.peticiones, isEmpty);
  });

  testWidgets('al abrir consulta la lista: no es favorito, corazón vacío', (
    tester,
  ) async {
    await abrirDetalle(tester, controlador);
    expect(api.metodos(), ['GET /favoritos/servicios']);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byTooltip(MensajesFavoritos.agregar), findsOneWidget);
  });

  testWidgets('si ya es favorito sale marcado y al tocarlo se quita', (
    tester,
  ) async {
    api.serviciosDe('ana').add(servicioFavorito('abc123', 's2'));
    await abrirDetalle(tester, controlador);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byTooltip(MensajesFavoritos.quitar), findsOneWidget);

    await tester.tap(find.byTooltip(MensajesFavoritos.quitar));
    await tester.pumpAndSettle();

    expect(api.metodos(), contains('DELETE /favoritos/servicios/abc123/s2'));
    expect(api.serviciosDe('ana'), isEmpty);
    expect(find.byTooltip(MensajesFavoritos.agregar), findsOneWidget);
  });

  testWidgets('el mismo servicioId de otro negocio no lo marca', (tester) async {
    api.serviciosDe('ana').add(servicioFavorito('otro', 's2'));
    await abrirDetalle(tester, controlador);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets(
    'agregar: queda marcado al instante, se deshabilita y luego se habilita',
    (tester) async {
      await abrirDetalle(tester, controlador);
      api.retener = Completer<void>();

      await tester.tap(find.byTooltip(MensajesFavoritos.agregar));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(boton(tester).onPressed, isNull);

      api.retener!.complete();
      await tester.pumpAndSettle();

      expect(api.metodos(), contains('PUT /favoritos/servicios/abc123/s2'));
      final guardado = api.serviciosDe('ana').single;
      expect(guardado['servicioId'], 's2');
      expect(guardado['negocioId'], 'abc123');
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(boton(tester).onPressed, isNotNull);
      expect(find.byTooltip(MensajesFavoritos.quitar), findsOneWidget);
    },
  );

  testWidgets('404: vuelve a su estado y dice «Este servicio no está disponible.»', (
    tester,
  ) async {
    await abrirDetalle(tester, controlador);
    api.serviciosNoDisponibles.add('abc123/s2');

    await tester.tap(find.byTooltip(MensajesFavoritos.agregar));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('Este servicio no está disponible.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(boton(tester).onPressed, isNotNull);
  });

  testWidgets('409: vuelve a su estado y muestra el mensaje de la API', (
    tester,
  ) async {
    await abrirDetalle(tester, controlador);
    api.topeServicios = 100;
    for (var i = 0; i < 100; i++) {
      api.serviciosDe('ana').add(servicioFavorito('n1', 'x$i'));
    }

    await tester.tap(find.byTooltip(MensajesFavoritos.agregar));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(
      find.text(
        'Llegaste al máximo de 100 servicios favoritos. Quita alguno para agregar otro.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('error de red: revierte y avisa sin diálogos', (tester) async {
    await abrirDetalle(tester, controlador);
    api.erroresServicios['PUT'] = (codigo: 500, mensaje: 'Falló');

    await tester.tap(find.byTooltip(MensajesFavoritos.agregar));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(
      find.text('La API no está disponible. Intenta más tarde.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('si falla quitar, el corazón vuelve a marcado', (tester) async {
    api.serviciosDe('ana').add(servicioFavorito('abc123', 's2'));
    await abrirDetalle(tester, controlador);
    api.erroresServicios['DELETE'] = (codigo: 500, mensaje: 'Falló');

    await tester.tap(find.byTooltip(MensajesFavoritos.quitar));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('si no se pudo consultar la lista, tocar el corazón reintenta', (
    tester,
  ) async {
    api.erroresServicios['GET'] = (codigo: 500, mensaje: 'Falló');
    await abrirDetalle(tester, controlador);
    expect(find.byTooltip(MensajesFavoritos.reintentarEstado), findsOneWidget);

    api.erroresServicios.clear();
    api.serviciosDe('ana').add(servicioFavorito('abc123', 's2'));
    await tester.tap(find.byTooltip(MensajesFavoritos.reintentarEstado));
    await tester.pumpAndSettle();

    expect(find.byTooltip(MensajesFavoritos.quitar), findsOneWidget);
  });

  testWidgets('el corazón tiene etiqueta accesible y área táctil de 48 dp', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await abrirDetalle(tester, controlador);

    final nodo = tester.getSemantics(_boton);
    expect(nodo.tooltip, MensajesFavoritos.agregar);
    expect(nodo.getSemanticsData().hasFlag(SemanticsFlag.isButton), isTrue);
    final tamano = tester.getSize(_boton);
    expect(tamano.width, greaterThanOrEqualTo(Medidas.tactil));
    expect(tamano.height, greaterThanOrEqualTo(Medidas.tactil));
    semantica.dispose();
  });
}
