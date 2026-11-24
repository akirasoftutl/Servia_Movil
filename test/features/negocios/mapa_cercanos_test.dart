import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/theme/colores_servia.dart';
import 'package:servia/core/widgets/estados.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/negocios/data/negocio_cercano.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/data/ubicacion_negocio.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/mapa_cercanos_page.dart';
import 'package:servia/features/negocios/pages/marcador_mapa.dart';
import 'package:servia/features/negocios/pages/negocios_cercanos.dart';
import 'package:servia/features/negocios/pages/tarjeta_negocio.dart';

import '../perfil/fakes_perfil.dart';

Map<String, Object?> _itemCercano(
  int id,
  double km, {
  Object? ubicacion = const {'lat': 21.12, 'lng': -101.68},
  bool incluirUbicacion = true,
}) => {
  'id': 'n$id',
  'nombre': 'Negocio $id',
  'categoriaId': 'cabello',
  'fotos': {'portada': null, 'galeria': <Object>[]},
  'aceptaReservas': true,
  'distanciaKm': km,
  if (incluirUbicacion) 'ubicacion': ubicacion,
};

String _cuerpo(List<Object?> items) => jsonEncode({'items': items});

NegociosService _servicioCercanos(
  Future<http.Response> Function(http.Request) cercanos,
) => NegociosService(
  api: ApiClient(
    client: MockClient((peticion) async {
      if (peticion.url.path == '/negocios/cercanos') return cercanos(peticion);
      if (peticion.url.path == '/categorias') return http.Response('[]', 200);
      if (peticion.url.path == '/negocios') {
        return http.Response('{"items":[],"siguiente":null}', 200);
      }
      if (peticion.url.path == '/negocios/destacados') {
        return http.Response('{"items":[]}', 200);
      }
      throw StateError('Petición inesperada: ${peticion.url.path}');
    }),
  ),
);

/// Mapa falso sin plataforma ni red que expone pines accesibles con Semantics.
Widget mapaFalso(
  BuildContext context,
  DatosMapaCercanos datos, {
  void Function(DatosMapaCercanos)? alRecibir,
}) {
  alRecibir?.call(datos);
  return ColoredBox(
    key: const Key('mapa-falso'),
    color: const Color(0xFFE5E7EB),
    child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Semantics(
              label: MensajesNegocios.tuUbicacion,
              child: const SizedBox.square(
                key: Key('punto-cliente'),
                dimension: 16,
              ),
            ),
            for (final pin in datos.pines)
              Semantics(
                button: true,
                selected: pin.seleccionado,
                label: pin.descripcionSemantica,
                child: Material(
                  color: pin.seleccionado
                      ? ColoresServia.morado
                      : const Color(0xFF0F0F0F),
                  shape: const StadiumBorder(),
                  child: InkWell(
                    key: Key('pin-${pin.id}'),
                    customBorder: const StadiumBorder(),
                    onTap: () => datos.onSeleccionarPin(pin.id),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: ExcludeSemantics(
                            child: Text(
                              pin.etiqueta,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _ServicioMapaDirecto extends NegociosService {
  _ServicioMapaDirecto(this._respuesta);
  final Future<List<NegocioCercano>> Function(double lat, double lng)
  _respuesta;

  @override
  Future<List<NegocioCercano>> obtenerCercanos({
    required double lat,
    required double lng,
  }) => _respuesta(lat, lng);
}

void main() {
  group('lectura tolerante de ubicación en modelos de cercanos', () {
    test('NegocioResumen y NegocioCercano leen ubicación válida', () {
      final json = _itemCercano(
        1,
        0.8,
        ubicacion: const {'lat': 21.123, 'lng': -101.682},
      );
      final resumen = NegocioResumen.fromJson(json);
      final cercano = NegocioCercano.fromJson(json);

      expect(resumen.ubicacion, isNotNull);
      expect(resumen.ubicacion!.lat, 21.123);
      expect(resumen.ubicacion!.lng, -101.682);
      expect(cercano.ubicacion!.lat, 21.123);
      expect(cercano.ubicacion!.lng, -101.682);
    });

    test('tolera ubicación ausente o malformada sin romper el item', () {
      final sinCampo = _itemCercano(1, 1.2, incluirUbicacion: false);
      expect(NegocioCercano.fromJson(sinCampo).ubicacion, isNull);

      for (final mala in [
        null,
        '21,-101',
        <Object>[],
        <String, Object?>{},
        {'lat': 21.1},
        {'lat': '21.1', 'lng': -101.6},
        {'lat': 95, 'lng': 0},
        {'lat': 0, 'lng': -185},
        {'lat': double.nan, 'lng': 0},
        {'lat': 0, 'lng': double.infinity},
      ]) {
        final cercano = NegocioCercano.fromJson(
          _itemCercano(2, 2.5, ubicacion: mala),
        );
        expect(cercano.negocio.id, 'n2', reason: '$mala');
        expect(cercano.ubicacion, isNull, reason: '$mala');
      }

      final enteros = NegocioCercano.fromJson(
        _itemCercano(3, 0.5, ubicacion: const {'lat': 0, 'lng': -101}),
      );
      expect(enteros.ubicacion!.lat, 0);
      expect(enteros.ubicacion!.lng, -101);
    });
  });

  group('marcador de distancia y cálculo de zoom', () {
    test('dibuja píldora PNG escalada por densidad y más grande al seleccionar', () async {
      final normal1x = await dibujarPinDistanciaPng(
        etiqueta: '0.8 km',
        seleccionado: false,
        pixelRatio: 1.0,
      );
      final normal2x = await dibujarPinDistanciaPng(
        etiqueta: '0.8 km',
        seleccionado: false,
        pixelRatio: 2.0,
      );
      final seleccionada1x = await dibujarPinDistanciaPng(
        etiqueta: '0.8 km',
        seleccionado: true,
        pixelRatio: 1.0,
      );

      expect(normal1x.bytes, isNotEmpty);
      expect(normal2x.anchoPx, greaterThan(normal1x.anchoPx));
      expect(normal2x.altoPx, greaterThan(normal1x.altoPx));
      expect(seleccionada1x.anchoPx, greaterThan(normal1x.anchoPx));
      expect(seleccionada1x.altoPx, greaterThan(normal1x.altoPx));
    });

    test('zoom inicial se ajusta a la dispersión alrededor del cliente', () {
      const cliente = (lat: 21.12, lng: -101.68);
      final zoomCerca = calcularZoomInicial(cliente, const [
        UbicacionNegocio(lat: 21.123, lng: -101.682),
      ]);
      final zoomLejos = calcularZoomInicial(cliente, const [
        UbicacionNegocio(lat: 21.25, lng: -101.55),
      ]);
      expect(zoomCerca, greaterThan(zoomLejos));
      expect(zoomLejos, inInclusiveRange(10.0, 16.0));
      expect(calcularZoomInicial(cliente, const []), 14.0);
    });
  });

  group('MapaCercanosPage', () {
    testWidgets(
      'un pin por negocio con ubicación, ninguno sin ella, etiqueta y Semantics',
      (tester) async {
        DatosMapaCercanos? ultimoEstado;
        await tester.pumpWidget(
          MaterialApp(
            home: MapaCercanosPage(
              proveedorUbicacion: () async => (lat: 21.12, lng: -101.68),
              negociosService: _servicioCercanos(
                (_) async => http.Response(
                  _cuerpo([
                    _itemCercano(
                      1,
                      0.8,
                      ubicacion: const {'lat': 21.125, 'lng': -101.681},
                    ),
                    _itemCercano(2, 1.5, incluirUbicacion: false),
                    _itemCercano(
                      3,
                      2.4,
                      ubicacion: const {'lat': 21.135, 'lng': -101.675},
                    ),
                  ]),
                  200,
                ),
              ),
              constructorMapa: (ctx, datos) =>
                  mapaFalso(ctx, datos, alRecibir: (d) => ultimoEstado = d),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('3 lugares cercanos'), findsOneWidget);
        expect(find.byType(TarjetaNegocio), findsNWidgets(3));
        expect(find.byKey(const Key('punto-cliente')), findsOneWidget);
        expect(ultimoEstado!.posicionCliente, (lat: 21.12, lng: -101.68));
        expect(ultimoEstado!.pines.map((p) => p.id), ['n1', 'n3']);
        expect(find.byKey(const Key('pin-n1')), findsOneWidget);
        expect(find.byKey(const Key('pin-n2')), findsNothing);
        expect(find.byKey(const Key('pin-n3')), findsOneWidget);

        expect(find.text('0.8 km'), findsOneWidget);
        expect(find.text('2.4 km'), findsOneWidget);
        expect(find.bySemanticsLabel('Negocio 1 a 0.8 km'), findsOneWidget);
        expect(find.bySemanticsLabel('Negocio 3 a 2.4 km'), findsOneWidget);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      },
    );

    testWidgets('tocar pin resalta su tarjeta y desplaza hasta mostrarla', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final listaLarga = [
        for (var i = 1; i <= 8; i++)
          NegocioCercano(
            negocio: NegocioResumen(
              id: 'n$i',
              nombre: 'Negocio $i',
              categoriaId: 'cabello',
              aceptaReservas: true,
              ubicacion: UbicacionNegocio(
                lat: 21.12 + i * 0.002,
                lng: -101.68 - i * 0.002,
              ),
            ),
            distanciaKm: i * 0.4,
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: MapaCercanosPage(
            proveedorUbicacion: () async => (lat: 21.12, lng: -101.68),
            negociosService: _ServicioMapaDirecto((_, _) async => listaLarga),
            constructorMapa: mapaFalso,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final posicionAntes = tester.getTopLeft(find.text('Negocio 8')).dy;
      expect(posicionAntes, greaterThan(640));

      await tester.tap(find.byKey(const Key('pin-n8')));
      await tester.pumpAndSettle();

      final posicionDespues = tester.getTopLeft(find.text('Negocio 8')).dy;
      expect(posicionDespues, lessThan(640));

      final contenedorResaltado = find.ancestor(
        of: find.text('Negocio 8'),
        matching: find.byWidgetPredicate(
          (w) =>
              w is AnimatedContainer &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).border ==
                  Border.all(color: ColoresServia.morado, width: 2),
        ),
      );
      expect(contenedorResaltado, findsOneWidget);
    });

    testWidgets('tocar tarjeta en la hoja abre el perfil del negocio', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (ajustes) => MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: Text('Perfil ${ajustes.name}')),
          ),
          home: MapaCercanosPage(
            proveedorUbicacion: () async => (lat: 21.12, lng: -101.68),
            negociosService: _servicioCercanos(
              (_) async => http.Response(
                _cuerpo([_itemCercano(1, 0.6)]),
                200,
              ),
            ),
            constructorMapa: mapaFalso,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 lugar cercano'), findsOneWidget);
      await tester.tap(find.text('Negocio 1'));
      await tester.pumpAndSettle();
      expect(find.text('Perfil /negocios/n1'), findsOneWidget);
    });

    testWidgets('muestra cargando, vacío, error y reintenta con nueva lectura', (
      tester,
    ) async {
      final pendiente = Completer<http.Response>();
      var llamadasUbicacion = 0;
      var llamadasApi = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MapaCercanosPage(
            proveedorUbicacion: () async {
              llamadasUbicacion++;
              return (lat: 21.12 + llamadasUbicacion * 0.01, lng: -101.68);
            },
            negociosService: _servicioCercanos((_) {
              llamadasApi++;
              if (llamadasApi == 1) return pendiente.future;
              return Future.value(http.Response(_cuerpo([]), 200));
            }),
            constructorMapa: mapaFalso,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(EstadoCargando), findsOneWidget);

      pendiente.complete(http.Response('{}', 503));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoError), findsOneWidget);
      expect(find.text(MensajesNegocios.errorCercanos), findsOneWidget);
      expect(find.text(MensajesNegocios.reintentar), findsOneWidget);

      await tester.tap(find.text(MensajesNegocios.reintentar));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoVacio), findsOneWidget);
      expect(find.text(MensajesNegocios.sinCercanos), findsOneWidget);
      expect(llamadasUbicacion, 2);
      expect(llamadasApi, 2);
    });
  });

  group('botón Ver mapa en Cerca de ti', () {
    testWidgets('solo aparece cuando ya se muestran cercanos y abre el mapa', (
      tester,
    ) async {
      final pendiente = Completer<http.Response>();
      var intento = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NegociosCercanos(
              proveedorUbicacion: () async => (lat: 21.12, lng: -101.68),
              constructorMapa: mapaFalso,
              service: _servicioCercanos((_) {
                intento++;
                if (intento == 1) return pendiente.future;
                if (intento == 2) {
                  return Future.value(http.Response(_cuerpo([]), 200));
                }
                return Future.value(
                  http.Response(_cuerpo([_itemCercano(1, 0.9)]), 200),
                );
              }),
            ),
          ),
        ),
      );

      // Cargando: no aparece.
      await tester.pump();
      expect(find.text(MensajesNegocios.verMapa), findsNothing);

      // Error: no aparece.
      pendiente.complete(http.Response('{}', 503));
      await tester.pumpAndSettle();
      expect(find.text(MensajesNegocios.verMapa), findsNothing);

      // Vacío: no aparece.
      await tester.tap(find.text(MensajesNegocios.reintentar));
      await tester.pumpAndSettle();
      expect(find.text(MensajesNegocios.sinCercanos), findsOneWidget);
      expect(find.text(MensajesNegocios.verMapa), findsNothing);

      // Con cercanos: aparece, cumple área táctil y abre el mapa.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NegociosCercanos(
              key: const ValueKey('con-cercanos'),
              proveedorUbicacion: () async => (lat: 21.12, lng: -101.68),
              constructorMapa: mapaFalso,
              service: _servicioCercanos(
                (_) async => http.Response(
                  _cuerpo([_itemCercano(1, 0.9)]),
                  200,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(MensajesNegocios.verMapa), findsOneWidget);
      expect(find.bySemanticsLabel(MensajesNegocios.verMapa), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      await tester.tap(find.text(MensajesNegocios.verMapa));
      await tester.pumpAndSettle();
      expect(find.byType(MapaCercanosPage), findsOneWidget);
      expect(find.byKey(const Key('mapa-falso')), findsOneWidget);
    });

    testWidgets('Ver mapa es tocable en HomePage incluso con sesión iniciada', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            onCerrarSesion: () {},
            authService: SesionPerfilFalsa([]),
            proveedorUbicacion: () async => (lat: 21.12, lng: -101.68),
            negociosService: _servicioCercanos(
              (_) async => http.Response(
                _cuerpo([_itemCercano(1, 0.7)]),
                200,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(MensajesNegocios.verMapa).hitTestable(), findsOneWidget);
    });
  });

  group('privacidad de la ubicación del cliente', () {
    testWidgets('no persiste ni reutiliza posición al fallar ubicación tras reintento', (
      tester,
    ) async {
      var disponibles = true;
      var llamadas = 0;
      final registros = <String>[];

      await runZoned(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: MapaCercanosPage(
                proveedorUbicacion: () async {
                  llamadas++;
                  return disponibles ? (lat: 21.12, lng: -101.68) : null;
                },
                negociosService: _servicioCercanos(
                  (_) async => http.Response('{}', 503),
                ),
                constructorMapa: mapaFalso,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(EstadoError), findsOneWidget);

          disponibles = false;
          await tester.tap(find.text(MensajesNegocios.reintentar));
          await tester.pumpAndSettle();
          expect(find.byType(EstadoVacio), findsOneWidget);
          expect(llamadas, 2);
        },
        zoneSpecification: ZoneSpecification(
          print: (_, _, _, texto) => registros.add(texto),
        ),
      );
      expect(registros, isEmpty);
    });

    test('código del mapa no persiste, no registra ni habilita seguimiento', () {
      for (final ruta in [
        'lib/features/negocios/pages/mapa_cercanos_page.dart',
        'lib/features/negocios/pages/marcador_mapa.dart',
        'lib/features/negocios/pages/negocios_cercanos.dart',
      ]) {
        final codigo = File(ruta).readAsStringSync();
        expect(
          codigo,
          isNot(
            matches(
              r'SharedPreferences|File\(|print\(|debugPrint|getPositionStream|getLastKnownPosition|myLocationEnabled:\s*true',
            ),
          ),
          reason: ruta,
        );
      }
    });
  });
}
