import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/inicio_con_mapa.dart';
import 'package:servia/features/negocios/pages/mapa_cercanos.dart';
import 'package:servia/features/negocios/pages/tarjeta_negocio.dart';

import '../perfil/fakes_perfil.dart';
import 'mapa_falso.dart';

Map<String, Object?> _item(int id, double km, {bool conUbicacion = true}) => {
  'id': 'n$id',
  'nombre': 'Negocio $id',
  'categoriaId': 'cabello',
  'fotos': {'portada': null, 'galeria': <Object>[]},
  'aceptaReservas': true,
  'distanciaKm': km,
  if (conUbicacion) 'ubicacion': {'lat': 21.12 + id * 0.002, 'lng': -101.68},
};

String _cuerpo(List<Object?> items) => jsonEncode({'items': items});

NegociosService _servicio(
  Future<http.Response> Function(http.Request) cercanos,
) => NegociosService(
  api: ApiClient(
    client: MockClient((peticion) async {
      switch (peticion.url.path) {
        case '/negocios/cercanos':
          return cercanos(peticion);
        case '/categorias':
          return http.Response('[]', 200);
        case '/negocios':
          return http.Response('{"items":[],"siguiente":null}', 200);
        case '/negocios/destacados':
          return http.Response('{"items":[]}', 200);
      }
      throw StateError('Petición inesperada: ${peticion.url.path}');
    }),
  ),
);

NegociosService _servicioCon(List<Object?> items) =>
    _servicio((_) async => http.Response(_cuerpo(items), 200));

Widget _inicio({
  NegociosService? servicio,
  Future<({double lat, double lng})?> Function()? ubicacion,
  double escalaTexto = 1,
  void Function(DatosMapaCercanos)? alRecibir,
}) => MaterialApp(
  onGenerateRoute: (ajustes) => MaterialPageRoute<void>(
    builder: (_) => Scaffold(body: Text('Perfil ${ajustes.name}')),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(escalaTexto)),
    child: child!,
  ),
  home: Scaffold(
    body: InicioConMapa(
      negociosService: servicio ?? _servicioCon([_item(1, 0.8), _item(2, 3.4)]),
      proveedorUbicacion: ubicacion ?? () async => (lat: 21.12, lng: -101.68),
      constructorMapa: (ctx, datos) =>
          mapaFalso(ctx, datos, alRecibir: alRecibir),
    ),
  ),
);

final _asa = find.byKey(const Key('asa-hoja-inicio'));
final _buscador = find.byType(TextField);
final _mapa = find.byKey(const Key('mapa-falso'));
final _contenido = find.text(MensajesNegocios.listaVacia);
final _tarjeta = find.byKey(const Key('tarjeta-flotante'));

Future<void> _preparar(WidgetTester tester, [Size? tamano]) async {
  tester.view.physicalSize = tamano ?? const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('el mapa es el fondo y la hoja trae el contenido del inicio', (
    tester,
  ) async {
    await _preparar(tester);
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(_inicio());
    await tester.pumpAndSettle();

    expect(_mapa, findsOneWidget);
    expect(_asa, findsOneWidget);
    expect(_buscador, findsOneWidget);
    expect(_contenido, findsOneWidget);
    // La hoja deja ver una franja del mapa arriba.
    expect(tester.getTopLeft(_asa).dy, greaterThan(200));
    expect(tester.getTopLeft(_asa).dy, lessThan(400));
    expect(find.bySemanticsLabel(MensajesNegocios.hojaAbierta), findsOneWidget);
    expect(
      find.bySemanticsLabel(MensajesNegocios.descripcionMapaCercanos),
      findsOneWidget,
    );
    semantica.dispose();
  });

  testWidgets('en «Cerca de ti» ya no hay nombres, tarjetas ni «Ver mapa»', (
    tester,
  ) async {
    await _preparar(tester);
    await tester.pumpWidget(_inicio());
    await tester.pumpAndSettle();

    expect(find.byType(TarjetaNegocio), findsNothing);
    expect(find.text('Negocio 1'), findsNothing);
    expect(find.text('Negocio 2'), findsNothing);
    expect(find.text('Ver mapa'), findsNothing);
    expect(find.text('Cerca de ti'), findsNothing);
    // Los pines con la distancia sí están sobre el mapa.
    expect(find.byKey(const Key('pin-n1')), findsOneWidget);
    expect(find.text('0.8 km'), findsOneWidget);
  });

  testWidgets(
    'arrastrar la hoja hacia abajo la colapsa y hacia arriba la abre',
    (tester) async {
      await _preparar(tester);
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(_inicio());
      await tester.pumpAndSettle();
      final abierta = tester.getTopLeft(_asa).dy;

      await tester.drag(_asa, const Offset(0, 300));
      await tester.pumpAndSettle();
      final colapsada = tester.getTopLeft(_asa).dy;
      expect(colapsada, greaterThan(abierta + 200));
      // Solo quedan a la vista el asa y la búsqueda, el mapa casi a pantalla completa.
      expect(_buscador.hitTestable(), findsOneWidget);
      expect(_contenido.hitTestable(), findsNothing);
      expect(
        find.bySemanticsLabel(MensajesNegocios.hojaColapsada),
        findsOneWidget,
      );
      semantica.dispose();

      await tester.drag(_asa, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_asa).dy, abierta);
      expect(_contenido.hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'un arrastre corto y lento regresa la hoja a su posición (snap)',
    (tester) async {
      await _preparar(tester);
      await tester.pumpWidget(_inicio());
      await tester.pumpAndSettle();
      final abierta = tester.getTopLeft(_asa).dy;

      final gesto = await tester.startGesture(tester.getCenter(_asa));
      await gesto.moveBy(const Offset(0, 30));
      await tester.pump();
      await gesto.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(tester.getTopLeft(_asa).dy, greaterThan(abierta));
      await gesto.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_asa).dy, abierta);
    },
  );

  testWidgets('tocar el asa alterna entre hoja abierta y colapsada', (
    tester,
  ) async {
    await _preparar(tester);
    await tester.pumpWidget(_inicio());
    await tester.pumpAndSettle();
    final abierta = tester.getTopLeft(_asa).dy;

    await tester.tap(_asa);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_asa).dy, greaterThan(abierta + 200));
    await tester.tap(_asa);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(_asa).dy, abierta);
  });

  testWidgets('el asa mide al menos 48 dp', (tester) async {
    await _preparar(tester);
    await tester.pumpWidget(_inicio());
    await tester.pumpAndSettle();
    expect(tester.getSize(_asa).height, greaterThanOrEqualTo(48));
  });

  testWidgets(
    'tirar hacia abajo del contenido arriba del todo colapsa la hoja',
    (tester) async {
      await _preparar(tester);
      await tester.pumpWidget(_inicio());
      await tester.pumpAndSettle();
      final abierta = tester.getTopLeft(_asa).dy;

      await tester.fling(_contenido, const Offset(0, 400), 1500);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_asa).dy, greaterThan(abierta + 200));
    },
  );

  group('tarjeta flotante', () {
    testWidgets('tocar un pin muestra nombre, distancia y reservas', (
      tester,
    ) async {
      await _preparar(tester);
      await tester.pumpWidget(_inicio());
      await tester.pumpAndSettle();
      expect(_tarjeta, findsNothing);

      await tester.tap(find.byKey(const Key('pin-n1')));
      await tester.pumpAndSettle();

      expect(_tarjeta, findsOneWidget);
      expect(
        find.descendant(of: _tarjeta, matching: find.text('Negocio 1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _tarjeta, matching: find.text('a 0.8 km')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _tarjeta,
          matching: find.text(MensajesNegocios.aceptaReservas),
        ),
        findsOneWidget,
      );
      // Flota sobre el mapa, justo encima de la hoja.
      expect(
        tester.getBottomLeft(_tarjeta).dy,
        lessThanOrEqualTo(tester.getTopLeft(_asa).dy),
      );
    });

    testWidgets('tocar otro pin cambia de negocio sin duplicar la tarjeta', (
      tester,
    ) async {
      await _preparar(tester);
      await tester.pumpWidget(_inicio());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pin-n1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pin-n2')));
      await tester.pumpAndSettle();

      expect(_tarjeta, findsOneWidget);
      expect(find.text('Negocio 2'), findsOneWidget);
      expect(find.text('Negocio 1'), findsNothing);
    });

    testWidgets('tocar la tarjeta abre el perfil del negocio', (tester) async {
      await _preparar(tester);
      await tester.pumpWidget(_inicio());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pin-n1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Negocio 1'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil /negocios/n1'), findsOneWidget);
    });

    testWidgets('tocar el mapa vacío cierra la tarjeta', (tester) async {
      await _preparar(tester);
      await tester.pumpWidget(_inicio());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pin-n1')));
      await tester.pumpAndSettle();
      expect(_tarjeta, findsOneWidget);

      await tester.tapAt(const Offset(340, 60));
      await tester.pumpAndSettle();
      expect(_tarjeta, findsNothing);
    });

    testWidgets('el padding del mapa deja libre la hoja y la tarjeta', (
      tester,
    ) async {
      await _preparar(tester);
      DatosMapaCercanos? datos;
      await tester.pumpWidget(_inicio(alRecibir: (d) => datos = d));
      await tester.pumpAndSettle();
      final sinTarjeta = datos!.padding.bottom;
      expect(sinTarjeta, closeTo(800 - tester.getTopLeft(_asa).dy, 1));

      await tester.tap(find.byKey(const Key('pin-n1')));
      await tester.pumpAndSettle();
      expect(datos!.padding.bottom, greaterThan(sinTarjeta));
      expect(datos!.seleccionadoId, 'n1');
    });
  });

  group('estados de «Cerca de ti» sobre el mapa', () {
    testWidgets(
      'cargando, error con Reintentar y vacío son un aviso discreto',
      (tester) async {
        await _preparar(tester);
        final pendiente = Completer<http.Response>();
        var intento = 0;
        await tester.pumpWidget(
          _inicio(
            servicio: _servicio((_) {
              intento++;
              if (intento == 1) return pendiente.future;
              return Future.value(http.Response(_cuerpo([]), 200));
            }),
          ),
        );
        await tester.pump();
        expect(_mapa, findsOneWidget);
        expect(find.text(MensajesNegocios.buscandoCercanos), findsOneWidget);

        pendiente.complete(http.Response('{}', 503));
        await tester.pumpAndSettle();
        expect(find.text(MensajesNegocios.errorCercanos), findsOneWidget);
        expect(find.text(MensajesNegocios.reintentar), findsOneWidget);
        expect(_mapa, findsOneWidget);

        await tester.tap(find.text(MensajesNegocios.reintentar));
        await tester.pumpAndSettle();
        expect(find.text(MensajesNegocios.sinCercanos), findsOneWidget);
        expect(find.text(MensajesNegocios.errorCercanos), findsNothing);
        expect(_mapa, findsOneWidget);
        expect(intento, 2);
      },
    );
  });

  group('sin mapa el inicio queda como antes', () {
    testWidgets('sin permiso o posición no hay mapa y la hoja ocupa todo', (
      tester,
    ) async {
      await _preparar(tester);
      await tester.pumpWidget(_inicio(ubicacion: () async => null));
      await tester.pumpAndSettle();
      expect(_mapa, findsNothing);
      expect(_asa, findsNothing);
      expect(find.text(MensajesNegocios.errorCercanos), findsNothing);
      expect(_contenido, findsOneWidget);
    });

    testWidgets('si ningún negocio trae ubicación válida no hay pines', (
      tester,
    ) async {
      await _preparar(tester);
      await tester.pumpWidget(
        _inicio(
          servicio: _servicioCon([
            _item(1, 1, conUbicacion: false),
            _item(2, 2, conUbicacion: false),
          ]),
        ),
      );
      await tester.pumpAndSettle();
      expect(_mapa, findsNothing);
      expect(_asa, findsNothing);
      expect(_contenido, findsOneWidget);
    });
  });

  testWidgets('HomePage muestra el mapa y ya no tiene «Ver mapa»', (
    tester,
  ) async {
    await _preparar(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onCerrarSesion: () {},
          authService: SesionPerfilFalsa([]),
          proveedorUbicacion: () async => (lat: 21.12, lng: -101.68),
          negociosService: _servicioCon([_item(1, 0.7)]),
          constructorMapa: mapaFalso,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_mapa, findsOneWidget);
    expect(_asa, findsOneWidget);
    expect(find.text('Ver mapa'), findsNothing);
    expect(find.byType(TarjetaNegocio), findsNothing);
  });
}
