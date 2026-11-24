import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/widgets/estados.dart';
import 'package:servia/features/favoritos/data/favoritos_controlador.dart';
import 'package:servia/features/favoritos/mensajes.dart';
import 'package:servia/features/favoritos/pages/favoritos_page.dart';
import 'package:servia/features/favoritos/rutas_favoritos.dart';
import 'package:servia/features/negocios/pages/tarjeta_negocio.dart';

import '../negocios/fakes.dart';
import 'fakes_favoritos.dart';

Future<void> abrir(
  WidgetTester tester,
  FavoritosControlador controlador, {
  List<String>? rutas,
}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      home: FavoritosPage(
        controlador: controlador,
        negociosService: NegociosServiceFalso(),
      ),
      onGenerateRoute: (ajustes) {
        rutas?.add(ajustes.name ?? '');
        return MaterialPageRoute<void>(
          settings: ajustes,
          builder: (_) => Scaffold(body: Text('Perfil ${ajustes.name}')),
        );
      },
    ),
  );
}

void main() {
  late ApiFavoritosFalsa api;
  late SesionFavoritos sesion;
  late FavoritosControlador controlador;

  setUp(() {
    api = ApiFavoritosFalsa();
    sesion = SesionFavoritos('ana');
    controlador = api.controlador(sesion);
  });

  testWidgets('muestra «Cargando» y luego solo los favoritos del cliente, del más reciente al más antiguo', (
    tester,
  ) async {
    api.de('ana').addAll([
      negocioFavorito('b2', nombre: 'Barbería Luna'),
      negocioFavorito('b1', nombre: 'Spa Aurora', aceptaReservas: false),
    ]);
    api.de('beto').add(negocioFavorito('x', nombre: 'Ajeno'));
    api.retener = Completer<void>();
    await abrir(tester, controlador);
    await tester.pump();
    expect(find.byType(EstadoCargando), findsOneWidget);

    api.retener!.complete();
    await tester.pumpAndSettle();

    expect(find.text(MensajesFavoritos.titulo), findsOneWidget);
    expect(find.byType(TarjetaNegocio), findsNWidgets(2));
    expect(find.text('Ajeno'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Barbería Luna')).dy,
      lessThan(tester.getTopLeft(find.text('Spa Aurora')).dy),
    );
    // La categoría sale con su nombre del catálogo.
    expect(find.text('Cabello y barba'), findsNWidgets(2));
  });

  testWidgets('sin favoritos: «Todavía no tienes negocios favoritos.»', (
    tester,
  ) async {
    await abrir(tester, controlador);
    await tester.pumpAndSettle();
    expect(find.byType(EstadoVacio), findsOneWidget);
    expect(find.text('Todavía no tienes negocios favoritos.'), findsOneWidget);
  });

  testWidgets('error: «No se pudieron cargar tus favoritos.» y Reintentar recarga', (
    tester,
  ) async {
    api.errores['GET'] = (codigo: 500, mensaje: 'Falló');
    await abrir(tester, controlador);
    await tester.pumpAndSettle();
    expect(find.byType(EstadoError), findsOneWidget);
    expect(find.text('No se pudieron cargar tus favoritos.'), findsOneWidget);

    api.errores.clear();
    api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.byType(EstadoError), findsNothing);
    expect(find.text('Spa Aurora'), findsOneWidget);
  });

  testWidgets('sesión vencida (401): lo dice y no ofrece reintentar', (
    tester,
  ) async {
    api.errores['GET'] = (codigo: 401, mensaje: 'Unauthorized');
    await abrir(tester, controlador);
    await tester.pumpAndSettle();
    expect(find.text(MensajesFavoritos.sesionVencida), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('tocar un favorito abre su perfil', (tester) async {
    api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
    final rutas = <String>[];
    await abrir(tester, controlador, rutas: rutas);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spa Aurora'));
    await tester.pumpAndSettle();

    expect(rutas, contains('/negocios/b1'));
    expect(find.text('Perfil /negocios/b1'), findsOneWidget);
  });

  testWidgets('quitar con el corazón lo saca de la lista sin recargar y al final queda el vacío', (
    tester,
  ) async {
    api.de('ana').addAll([
      negocioFavorito('b2', nombre: 'Barbería Luna'),
      negocioFavorito('b1', nombre: 'Spa Aurora'),
    ]);
    await abrir(tester, controlador);
    await tester.pumpAndSettle();
    final consultas = api.metodos().where((m) => m.startsWith('GET')).length;

    await tester.tap(find.byTooltip(MensajesFavoritos.quitar).first);
    await tester.pump();
    // Al instante, sin esperar a la API ni volver a consultar.
    expect(find.text('Barbería Luna'), findsNothing);
    expect(find.text('Spa Aurora'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(api.metodos().where((m) => m.startsWith('GET')).length, consultas);
    expect(api.de('ana').map((n) => n['id']), ['b1']);

    await tester.tap(find.byTooltip(MensajesFavoritos.quitar));
    await tester.pumpAndSettle();
    expect(find.text('Todavía no tienes negocios favoritos.'), findsOneWidget);
  });

  testWidgets('si quitar falla, el negocio vuelve a la lista y se avisa', (
    tester,
  ) async {
    api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
    await abrir(tester, controlador);
    await tester.pumpAndSettle();
    api.errores['DELETE'] = (codigo: 500, mensaje: 'Falló');

    await tester.tap(find.byTooltip(MensajesFavoritos.quitar));
    await tester.pumpAndSettle();

    expect(find.text('Spa Aurora'), findsOneWidget);
    expect(find.text('La API no está disponible. Intenta más tarde.'), findsOneWidget);
  });

  testWidgets('al entrar con otra cuenta no se ven los favoritos de la anterior', (
    tester,
  ) async {
    api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
    await abrir(tester, controlador);
    await tester.pumpAndSettle();
    expect(find.text('Spa Aurora'), findsOneWidget);

    sesion.usuario = UsuarioFavoritos('beto');
    await abrir(tester, controlador);
    await tester.pumpAndSettle();

    expect(find.text('Spa Aurora'), findsNothing);
    expect(find.text('Todavía no tienes negocios favoritos.'), findsOneWidget);
  });

  testWidgets('la ruta /favoritos abre «Mis favoritos»', (tester) async {
    final ruta = generarRutaFavoritos(const RouteSettings(name: '/favoritos'));
    expect(ruta, isNotNull);
    expect(generarRutaFavoritos(const RouteSettings(name: '/otra')), isNull);
  });

  testWidgets('las tarjetas y los corazones se anuncian con etiqueta y miden 48 dp', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
    await abrir(tester, controlador);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(MensajesFavoritos.quitar), findsOneWidget);
    final tamano = tester.getSize(find.byType(IconButton));
    expect(tamano.width, greaterThanOrEqualTo(48));
    expect(tamano.height, greaterThanOrEqualTo(48));
    semantica.dispose();
  });
}
