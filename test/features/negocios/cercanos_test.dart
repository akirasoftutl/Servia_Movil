import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/data/ubicacion_cliente.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/tarjeta_negocio.dart';

import '../perfil/fakes_perfil.dart';
import 'mapa_falso.dart';

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
  'fotos': {'portada': null, 'galeria': <Object>[]},
  'aceptaReservas': true,
  'distanciaKm': km,
};

Map<String, Object> conUbicacion(Map<String, Object> negocio) => {
  ...negocio,
  'ubicacion': {'lat': 21.12, 'lng': -101.68},
};

/// Cuerpo real de `GET /negocios/cercanos` (RespuestaNegociosCercanosDto).
String cuerpoCercanos(List<Object?> items) => jsonEncode({'items': items});

NegociosService servicio({
  required Future<http.Response> Function(http.Request) cercanos,
}) => NegociosService(
  api: ApiClient(
    client: MockClient((peticion) async {
      if (peticion.url.path == '/negocios/cercanos') return cercanos(peticion);
      if (peticion.url.path == '/categorias') return http.Response(cuerpoCercanos([]), 200);
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
        constructorMapa: mapaFalso,
      ),
      onGenerateRoute: (ajustes) => MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Text('Perfil ${ajustes.name}')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('concedido: radio, orden, cinco pines, distancia y perfil', (
    tester,
  ) async {
    final ubicacion = UbicacionFalsa();
    final consultas = <http.Request>[];
    final api = servicio(
      cercanos: (peticion) async {
        consultas.add(peticion);
        return http.Response(
          cuerpoCercanos([
            conUbicacion(cercano(6, 6)),
            conUbicacion(cercano(2, 1.2)),
            conUbicacion(cercano(1, 0.5)),
            conUbicacion(cercano(3, 3)),
            conUbicacion(cercano(4, 4)),
            conUbicacion(cercano(5, 5)),
            conUbicacion(cercano(7, 20.1)),
          ]),
          200,
        );
      },
    );
    await inicio(tester, ubicacion, api);
    expect(consultas.single.method, 'GET');
    expect(consultas.single.url.queryParameters, {
      'lat': '21.1',
      'lng': '-101.7',
      'radioKm': '20',
    });
    expect(consultas.single.headers.containsKey('authorization'), isFalse);
    // Solo mapa con pines: nada de nombres ni tarjetas en la sección.
    expect(find.byType(TarjetaNegocio), findsNothing);
    expect(find.text('Negocio 1'), findsNothing);
    expect(find.text('0.5 km'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    expect(find.byKey(const Key('pin-n5')), findsOneWidget);
    expect(find.byKey(const Key('pin-n6')), findsNothing);
    final resultado = await api.obtenerCercanos(lat: 21.1, lng: -101.7);
    expect(resultado.map((c) => c.negocio.id), ['n1', 'n2', 'n3', 'n4', 'n5']);
    expect(ubicacion.solicitudes, 1);
    expect(ubicacion.ajustes!.accuracy, LocationAccuracy.low);
    expect(ubicacion.ajustes!.timeLimit, const Duration(seconds: 10));
    await tester.tap(find.byKey(const Key('pin-n1')));
    await tester.pumpAndSettle();
    expect(find.text('a 0.5 km'), findsOneWidget);
    await tester.tap(find.text('Negocio 1'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil /negocios/n1'), findsOneWidget);
  });

  for (final caso in ['negado', 'permanente', 'gps', 'sin posición']) {
    testWidgets('$caso: sin mapa ni error y conserva búsqueda y lista', (
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
            return http.Response(cuerpoCercanos([]), 200);
          },
        ),
      );
      expect(find.byKey(const Key('mapa-falso')), findsNothing);
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
            consultas == 1 ? '{}' : cuerpoCercanos([]),
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

  testWidgets('muestra aviso de carga mientras responde la API', (tester) async {
    final pendiente = Completer<http.Response>();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          onCerrarSesion: () {},
          authService: SesionPerfilFalsa([])..usuario = null,
          proveedorUbicacion: () async => (lat: 21.1, lng: -101.7),
          negociosService: servicio(cercanos: (_) => pendiente.future),
          constructorMapa: mapaFalso,
        ),
      ),
    );
    await tester.pump();
    expect(find.text(MensajesNegocios.buscandoCercanos), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    pendiente.complete(http.Response(cuerpoCercanos([]), 200));
    await tester.pumpAndSettle();
    expect(find.text(MensajesNegocios.sinCercanos), findsOneWidget);
    expect(find.text(MensajesNegocios.buscandoCercanos), findsNothing);
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
            cuerpoCercanos([
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
            http.Response(cuerpoCercanos([cercano(7, 20.1)]), 200),
      );
      expect(await api.obtenerCercanos(lat: 21, lng: -101), isEmpty);
    },
  );

  test('cercanos lee items del contrato real y ordena con tope de 5', () async {
    final api = servicio(
      cercanos: (_) async => http.Response(
        cuerpoCercanos([
          cercano(3, 3),
          cercano(1, 1),
          cercano(2, 2),
          cercano(4, 4),
          cercano(5, 5),
          cercano(6, 6),
        ]),
        200,
      ),
    );
    final resultado = await api.obtenerCercanos(lat: 21, lng: -101);
    expect(resultado.map((c) => c.negocio.id), ['n1', 'n2', 'n3', 'n4', 'n5']);
  });

  for (final cuerpo in [
    '[]',
    '{}',
    '{"items":null}',
    '{"items":{}}',
    '{"items":"x"}',
  ]) {
    test('cercanos rechaza cuerpo sin items lista: $cuerpo', () async {
      final api = servicio(cercanos: (_) async => http.Response(cuerpo, 200));
      await expectLater(
        api.obtenerCercanos(lat: 21, lng: -101),
        throwsFormatException,
      );
    });
  }
}
