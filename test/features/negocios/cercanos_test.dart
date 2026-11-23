import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/theme/tokens.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/data/ubicacion_cliente.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';
import 'package:servia/features/negocios/pages/tarjeta_negocio.dart';
import 'package:servia/features/negocios/pages/negocios_cercanos.dart';

import '../perfil/fakes_perfil.dart';

class UbicacionFalsa extends GeolocatorPlatform {
  bool gps = true;
  bool falla = false;
  LocationPermission permiso = LocationPermission.denied;
  LocationPermission respuesta = LocationPermission.whileInUse;
  int solicitudes = 0;
  int posiciones = 0;
  LocationSettings? ajustes;
  @override
  Future<bool> isLocationServiceEnabled() async => gps;
  @override
  Future<LocationPermission> checkPermission() async => permiso;
  @override
  Future<LocationPermission> requestPermission() async {
    solicitudes++;
    return respuesta;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    posiciones++;
    ajustes = locationSettings;
    if (falla) throw const LocationServiceDisabledException();
    return Position(
      longitude: -101.7,
      latitude: 21.1,
      timestamp: DateTime(2026),
      accuracy: 1000,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

Map<String, Object> cercano(int id, double km) => {
  'id': 'n$id',
  'nombre': 'Negocio $id',
  'categoriaId': 'cabello',
  'aceptaReservas': true,
  'distanciaKm': km,
};

NegociosService servicio({
  required Future<http.Response> Function(http.Request) cercanos,
}) => NegociosService(
  api: ApiClient(
    client: MockClient((peticion) async {
      if (peticion.url.path == '/negocios/cercanos') return cercanos(peticion);
      if (peticion.url.path == '/categorias') return http.Response('[]', 200);
      if (peticion.url.path == '/negocios') {
        return http.Response('{"items":[],"siguiente":null}', 200);
      }
      throw StateError('Petición inesperada: ${peticion.url.path}');
    }),
  ),
);

Future<void> inicio(
  WidgetTester tester,
  UbicacionFalsa ubicacion,
  NegociosService negocios,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        onCerrarSesion: () {},
        authService: SesionPerfilFalsa([])..usuario = null,
        negociosService: negocios,
        proveedorUbicacion: UbicacionCliente(plataforma: ubicacion).obtener,
      ),
      onGenerateRoute: (ajustes) => MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Text('Perfil ${ajustes.name}')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final falla in [false, true]) {
    testWidgets('mensajes de cercanos alineados con el título: error=$falla', (
      tester,
    ) async {
      await inicio(
        tester,
        UbicacionFalsa(),
        servicio(
          cercanos: (_) async =>
              http.Response(falla ? '{}' : '[]', falla ? 503 : 200),
        ),
      );
      final titulo = tester.getTopLeft(find.text(MensajesNegocios.cercaDeTi));
      final mensaje = tester.getTopLeft(
        find.text(
          falla ? MensajesNegocios.errorCercanos : MensajesNegocios.sinCercanos,
        ),
      );
      expect(
        titulo.dx - tester.getTopLeft(find.byType(NegociosCercanos)).dx,
        Espacios.l,
      );
      expect(mensaje.dx, titulo.dx);
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.text(
                falla
                    ? MensajesNegocios.errorCercanos
                    : MensajesNegocios.sinCercanos,
              ),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: Espacios.l),
      );
    });
  }

  testWidgets(
    '«Cerca de ti» queda bajo la barra de estado sobre fondo blanco',
    (tester) async {
      const barra = 40.0;
      tester.view.padding = FakeViewPadding(
        top: barra * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetPadding);
      await inicio(
        tester,
        UbicacionFalsa(),
        servicio(cercanos: (_) async => http.Response('[]', 200)),
      );
      expect(
        tester.getTopLeft(find.text(MensajesNegocios.cercaDeTi)).dy,
        greaterThanOrEqualTo(barra),
      );
      // La lista ya no suma otro hueco de la barra debajo de la sección.
      expect(
        MediaQuery.paddingOf(tester.element(find.byType(ListaNegocios))).top,
        0,
      );
      expect(
        find.ancestor(
          of: find.byType(NegociosCercanos),
          matching: find.byWidgetPredicate(
            (w) => w is ColoredBox && w.color == Colors.white,
          ),
        ),
        findsOneWidget,
      );
    },
  );

  for (final acepta in [false, true]) {
    testWidgets('tarjeta completa a escala 2.0: acepta reservas=$acepta', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: Column(
                children: [
                  NegociosCercanos(
                    proveedorUbicacion: () async => (lat: 21.1, lng: -101.7),
                    service: servicio(
                      cercanos: (_) async => http.Response(
                        jsonEncode([
                          {
                            ...cercano(1, 19.9),
                            'nombre': 'Peluquería del centro histórico',
                            'aceptaReservas': acepta,
                          },
                          cercano(2, 20),
                        ]),
                        200,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final tarjeta = find.byType(TarjetaNegocio).first;
      expect(tester.getSize(tarjeta).width, 300);
      final limites = tester.getRect(
        find.descendant(of: tarjeta, matching: find.byType(Card)),
      );
      final textos = find.descendant(of: tarjeta, matching: find.byType(Text));
      expect(textos, findsNWidgets(4));
      for (final texto in textos.evaluate()) {
        final rect = tester.getRect(find.byWidget(texto.widget));
        expect(rect.left, greaterThanOrEqualTo(limites.left));
        expect(rect.right, lessThanOrEqualTo(limites.right));
        expect(rect.top, greaterThanOrEqualTo(limites.top));
        expect(rect.bottom, lessThanOrEqualTo(limites.bottom));
      }
      for (final mensaje in [
        'a 19.9 km',
        acepta
            ? MensajesNegocios.aceptaReservas
            : MensajesNegocios.noAceptaReservas,
      ]) {
        final parrafo = tester.renderObject<RenderParagraph>(
          find.descendant(of: tarjeta, matching: find.text(mensaje)),
        );
        expect(parrafo.didExceedMaxLines, isFalse);
      }
      final fila = find
          .ancestor(of: tarjeta, matching: find.byType(Scrollable))
          .first;
      expect(limites.bottom, lessThanOrEqualTo(tester.getRect(fila).bottom));
      await tester.drag(fila, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Negocio 2').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('concedido: radio, orden, cinco tarjetas, distancia y perfil', (
    tester,
  ) async {
    final ubicacion = UbicacionFalsa();
    final consultas = <http.Request>[];
    final api = servicio(
      cercanos: (peticion) async {
        consultas.add(peticion);
        return http.Response(
          jsonEncode([
            cercano(6, 6),
            cercano(2, 1.2),
            cercano(1, 0.5),
            cercano(3, 3),
            cercano(4, 4),
            cercano(5, 5),
            cercano(7, 20.1),
          ]),
          200,
        );
      },
    );
    await inicio(tester, ubicacion, api);
    expect(find.text(MensajesNegocios.cercaDeTi), findsOneWidget);
    expect(consultas.single.method, 'GET');
    expect(consultas.single.url.queryParameters, {
      'lat': '21.1',
      'lng': '-101.7',
      'radioKm': '20',
    });
    expect(consultas.single.headers.containsKey('authorization'), isFalse);
    final tarjetas = tester.widgetList<TarjetaNegocio>(
      find.byType(TarjetaNegocio, skipOffstage: false),
    );
    expect(tarjetas.take(2).map((t) => t.negocio.id), ['n1', 'n2']);
    final resultado = await api.obtenerCercanos(lat: 21.1, lng: -101.7);
    expect(resultado.map((c) => c.negocio.id), ['n1', 'n2', 'n3', 'n4', 'n5']);
    expect(find.text('a 0.5 km'), findsOneWidget);
    expect(find.text('a 1.2 km'), findsOneWidget);
    expect(ubicacion.solicitudes, 1);
    expect(ubicacion.ajustes!.accuracy, LocationAccuracy.low);
    expect(ubicacion.ajustes!.timeLimit, const Duration(seconds: 10));
    await tester.tap(find.text('Negocio 1'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil /negocios/n1'), findsOneWidget);
  });

  for (final caso in ['negado', 'permanente', 'gps', 'sin posición']) {
    testWidgets('$caso: oculta sin error y conserva búsqueda y lista', (
      tester,
    ) async {
      final ubicacion = UbicacionFalsa();
      switch (caso) {
        case 'negado':
          ubicacion.respuesta = LocationPermission.denied;
        case 'permanente':
          ubicacion.permiso = LocationPermission.deniedForever;
        case 'gps':
          ubicacion.gps = false;
        case 'sin posición':
          ubicacion.falla = true;
      }
      var consultas = 0;
      await inicio(
        tester,
        ubicacion,
        servicio(
          cercanos: (_) async {
            consultas++;
            return http.Response('[]', 200);
          },
        ),
      );
      expect(find.text(MensajesNegocios.cercaDeTi), findsNothing);
      expect(find.text(MensajesNegocios.errorCercanos), findsNothing);
      expect(find.text(MensajesNegocios.reintentar), findsNothing);
      expect(find.text('Explorar todos los servicios'), findsOneWidget);
      expect(find.text(MensajesNegocios.listaVacia), findsOneWidget);
      expect(consultas, 0);
      if (caso != 'sin posición') expect(ubicacion.posiciones, 0);
      if (caso == 'permanente' || caso == 'gps') {
        expect(ubicacion.solicitudes, 0);
      }
    });
  }

  testWidgets('API falla, reintenta con posición nueva y muestra vacío', (
    tester,
  ) async {
    var consultas = 0;
    final ubicacion = UbicacionFalsa();
    await inicio(
      tester,
      ubicacion,
      servicio(
        cercanos: (_) async {
          consultas++;
          return http.Response(
            consultas == 1 ? '{}' : '[]',
            consultas == 1 ? 503 : 200,
          );
        },
      ),
    );
    expect(find.text(MensajesNegocios.errorCercanos), findsOneWidget);
    await tester.tap(find.text(MensajesNegocios.reintentar));
    await tester.pumpAndSettle();
    expect(find.text(MensajesNegocios.sinCercanos), findsOneWidget);
    expect(find.text(MensajesNegocios.errorCercanos), findsNothing);
    expect(consultas, 2);
    expect(ubicacion.posiciones, 2);
  });

  testWidgets('muestra indicador mientras responde la API', (tester) async {
    final pendiente = Completer<http.Response>();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onCerrarSesion: () {},
          authService: SesionPerfilFalsa([])..usuario = null,
          proveedorUbicacion: () async => (lat: 21.1, lng: -101.7),
          negociosService: servicio(cercanos: (_) => pendiente.future),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(MensajesNegocios.cercaDeTi), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pendiente.complete(http.Response('[]', 200));
    await tester.pumpAndSettle();
    expect(find.text(MensajesNegocios.sinCercanos), findsOneWidget);
  });

  test('privacidad: no reutiliza posición ni registra coordenadas', () async {
    final plataforma = UbicacionFalsa();
    final proveedor = UbicacionCliente(plataforma: plataforma);
    final registros = <String>[];
    await runZoned(
      () async {
        expect(await proveedor.obtener(), (lat: 21.1, lng: -101.7));
        plataforma.gps = false;
        expect(await proveedor.obtener(), isNull);
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, texto) => registros.add(texto),
      ),
    );
    expect(registros, isEmpty);
    expect(plataforma.posiciones, 1);
  });

  test(
    'privacidad: solo coarse, sin persistencia ni seguimiento en proveedor',
    () {
      final manifiesto = File('android/app/src/main/AndroidManifest.xml')
          .readAsStringSync();
      expect(manifiesto, contains('android.permission.ACCESS_COARSE_LOCATION'));
      expect(manifiesto, isNot(contains('ACCESS_FINE_LOCATION')));
      expect(manifiesto, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
      final proveedor = File(
        'lib/features/negocios/data/ubicacion_cliente.dart',
      ).readAsStringSync();
      expect(
        proveedor,
        isNot(
          matches(
            r'getPositionStream|getLastKnownPosition|print\(|debugPrint|SharedPreferences|File\(',
          ),
        ),
      );
    },
  );

  test(
    'cercanos rechaza distancia malformada y excluye fuera del radio',
    () async {
      for (final distancia in [-1, '1.2', null]) {
        final api = servicio(
          cercanos: (_) async => http.Response(
            jsonEncode([
              {...cercano(1, 1), 'distanciaKm': distancia},
            ]),
            200,
          ),
        );
        await expectLater(
          api.obtenerCercanos(lat: 21, lng: -101),
          throwsFormatException,
        );
      }
      final api = servicio(
        cercanos: (_) async =>
            http.Response(jsonEncode([cercano(7, 20.1)]), 200),
      );
      expect(await api.obtenerCercanos(lat: 21, lng: -101), isEmpty);
    },
  );
}
