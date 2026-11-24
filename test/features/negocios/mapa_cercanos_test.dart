import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

class _ControladorMapaFalso extends Fake implements GoogleMapController {
  final List<CameraUpdate> animaciones = [];
  bool desechado = false;

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    animaciones.add(cameraUpdate);
  }

  @override
  void dispose() {
    desechado = true;
  }
}

BitmapDescriptor _iconoPrueba(int id, {double escala = 1.0}) =>
    BitmapDescriptor.bytes(
      Uint8List.fromList([id]),
      imagePixelRatio: escala,
    );

PinNegocioMapa _pinPrueba(
  int id,
  double km, {
  required double lat,
  required double lng,
  bool seleccionado = false,
}) => PinNegocioMapa(
  cercano: NegocioCercano(
    negocio: NegocioResumen(
      id: 'n$id',
      nombre: 'Negocio $id',
      categoriaId: 'cabello',
      aceptaReservas: true,
      ubicacion: UbicacionNegocio(lat: lat, lng: lng),
    ),
    distanciaKm: km,
  ),
  ubicacion: UbicacionNegocio(lat: lat, lng: lng),
  seleccionado: seleccionado,
);

Marker? _buscarMarcador(Set<Marker> marcadores, String id) {
  for (final m in marcadores) {
    if (m.markerId.value == id) return m;
  }
  return null;
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

  group('VistaGoogleMap (vista real del mapa)', () {
    testWidgets(
      'F1 respaldo: al seleccionar un pin nunca desaparece mientras se genera su icono seleccionado',
      (tester) async {
        final iconoCliente = _iconoPrueba(0);
        final iconoN1Normal = _iconoPrueba(1);
        final iconoN1Sel = _iconoPrueba(2);
        final iconoN2Normal = _iconoPrueba(3);
        final iconoN2Sel = _iconoPrueba(4);
        final pendienteN1Sel = Completer<BitmapDescriptor>();
        var marcadoresActuales = <Marker>{};
        String? tocadoId;

        DatosMapaCercanos construirDatos(String? seleccionadoId) =>
            DatosMapaCercanos(
              posicionCliente: (lat: 21.12, lng: -101.68),
              pines: [
                _pinPrueba(
                  1,
                  0.8,
                  lat: 21.125,
                  lng: -101.681,
                  seleccionado: seleccionadoId == 'n1',
                ),
                _pinPrueba(
                  2,
                  1.5,
                  lat: 21.135,
                  lng: -101.675,
                  seleccionado: seleccionadoId == 'n2',
                ),
              ],
              seleccionadoId: seleccionadoId,
              zoomInicial: 14,
              onSeleccionarPin: (id) => tocadoId = id,
            );

        Widget construir(String? seleccionadoId) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              devicePixelRatio: 1.0,
            ),
            child: VistaGoogleMap(
              datos: construirDatos(seleccionadoId),
              generadorIconoCliente: ({required pixelRatio}) async =>
                  iconoCliente,
              generadorIconoPin:
                  ({
                    required etiqueta,
                    required seleccionado,
                    required pixelRatio,
                  }) {
                    if (etiqueta == '0.8 km') {
                      if (seleccionado) return pendienteN1Sel.future;
                      return Future.value(iconoN1Normal);
                    }
                    return Future.value(
                      seleccionado ? iconoN2Sel : iconoN2Normal,
                    );
                  },
              constructorMapaNativo:
                  ({
                    required camaraInicial,
                    required marcadores,
                    required padding,
                    required onMapCreated,
                  }) {
                    marcadoresActuales = marcadores;
                    return const SizedBox.expand();
                  },
            ),
          ),
        );

        await tester.pumpWidget(construir(null));
        await tester.pump();

        expect(_buscarMarcador(marcadoresActuales, 'cliente'), isNotNull);
        final n1Inicial = _buscarMarcador(marcadoresActuales, 'negocio-n1');
        expect(n1Inicial, isNotNull);
        expect(n1Inicial!.icon, same(iconoN1Normal));
        expect(n1Inicial.zIndexInt, 2);

        // Seleccionamos n1 mientras su variante seleccionada sigue en curso.
        await tester.pumpWidget(construir('n1'));
        final n1Pendiente = _buscarMarcador(marcadoresActuales, 'negocio-n1');
        expect(n1Pendiente, isNotNull);
        expect(n1Pendiente!.icon, same(iconoN1Normal));
        expect(n1Pendiente.zIndexInt, 3);
        n1Pendiente.onTap?.call();
        expect(tocadoId, 'n1');

        // Al completarse el icono seleccionado, se sustituye sin desaparecer.
        pendienteN1Sel.complete(iconoN1Sel);
        await tester.pumpAndSettle();
        final n1Final = _buscarMarcador(marcadoresActuales, 'negocio-n1');
        expect(n1Final, isNotNull);
        expect(n1Final!.icon, same(iconoN1Sel));
      },
    );

    testWidgets(
      'F1 precálculo: ambas variantes están listas para cambiar de icono en el mismo cuadro',
      (tester) async {
        final iconoCliente = _iconoPrueba(10);
        final iconoNormal = _iconoPrueba(11);
        final iconoSel = _iconoPrueba(12);
        var llamadasPin = 0;
        var marcadoresActuales = <Marker>{};

        Widget construir(String? seleccionadoId) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              devicePixelRatio: 2.0,
            ),
            child: VistaGoogleMap(
              datos: DatosMapaCercanos(
                posicionCliente: (lat: 21.12, lng: -101.68),
                pines: [
                  _pinPrueba(
                    1,
                    0.8,
                    lat: 21.125,
                    lng: -101.681,
                    seleccionado: seleccionadoId == 'n1',
                  ),
                ],
                seleccionadoId: seleccionadoId,
                zoomInicial: 14,
                onSeleccionarPin: (_) {},
              ),
              generadorIconoCliente: ({required pixelRatio}) async =>
                  iconoCliente,
              generadorIconoPin:
                  ({
                    required etiqueta,
                    required seleccionado,
                    required pixelRatio,
                  }) async {
                    llamadasPin++;
                    return seleccionado ? iconoSel : iconoNormal;
                  },
              constructorMapaNativo:
                  ({
                    required camaraInicial,
                    required marcadores,
                    required padding,
                    required onMapCreated,
                  }) {
                    marcadoresActuales = marcadores;
                    return const SizedBox.expand();
                  },
            ),
          ),
        );

        await tester.pumpWidget(construir(null));
        await tester.pumpAndSettle();
        expect(llamadasPin, 2);

        // En el mismo cuadro de la selección ya existe el icono seleccionado
        // sin generar iconos nuevos.
        await tester.pumpWidget(construir('n1'));
        final marcador = _buscarMarcador(marcadoresActuales, 'negocio-n1');
        expect(marcador, isNotNull);
        expect(marcador!.icon, same(iconoSel));
        expect(llamadasPin, 2);
      },
    );

    testWidgets(
      'F4 concurrencia: actualizaciones simultáneas no generan el mismo icono dos veces',
      (tester) async {
        var llamadasCliente = 0;
        final llamadasPin = <String, int>{};
        final pendientesPin = <String, Completer<BitmapDescriptor>>{};
        final pendienteCliente = Completer<BitmapDescriptor>();

        Widget construir({required double zoom, String? seleccionadoId}) =>
            MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 640),
                  devicePixelRatio: 2.0,
                ),
                child: VistaGoogleMap(
                  datos: DatosMapaCercanos(
                    posicionCliente: (lat: 21.12, lng: -101.68),
                    pines: [
                      _pinPrueba(
                        1,
                        0.8,
                        lat: 21.125,
                        lng: -101.681,
                        seleccionado: seleccionadoId == 'n1',
                      ),
                      // Misma etiqueta de distancia que n1 para probar caché compartida.
                      _pinPrueba(
                        2,
                        0.8,
                        lat: 21.126,
                        lng: -101.682,
                        seleccionado: seleccionadoId == 'n2',
                      ),
                      _pinPrueba(
                        3,
                        1.4,
                        lat: 21.135,
                        lng: -101.675,
                        seleccionado: seleccionadoId == 'n3',
                      ),
                    ],
                    seleccionadoId: seleccionadoId,
                    zoomInicial: zoom,
                    onSeleccionarPin: (_) {},
                  ),
                  generadorIconoCliente: ({required pixelRatio}) {
                    llamadasCliente++;
                    return pendienteCliente.future;
                  },
                  generadorIconoPin:
                      ({
                        required etiqueta,
                        required seleccionado,
                        required pixelRatio,
                      }) {
                        final clave = '$etiqueta|$seleccionado|$pixelRatio';
                        llamadasPin[clave] = (llamadasPin[clave] ?? 0) + 1;
                        return pendientesPin
                            .putIfAbsent(clave, Completer<BitmapDescriptor>.new)
                            .future;
                      },
                  constructorMapaNativo:
                      ({
                        required camaraInicial,
                        required marcadores,
                        required padding,
                        required onMapCreated,
                      }) => const SizedBox.expand(),
                ),
              ),
            );

        await tester.pumpWidget(construir(zoom: 14));
        // Varias actualizaciones mientras los futuros siguen en vuelo.
        await tester.pumpWidget(construir(zoom: 14.5, seleccionadoId: 'n1'));
        await tester.pumpWidget(construir(zoom: 15.0, seleccionadoId: 'n2'));
        await tester.pumpWidget(construir(zoom: 15.0, seleccionadoId: 'n3'));

        expect(llamadasCliente, 1);
        expect(llamadasPin, {
          '0.8 km|false|2.0': 1,
          '0.8 km|true|2.0': 1,
          '1.4 km|false|2.0': 1,
          '1.4 km|true|2.0': 1,
        });

        // Al completar y volver a actualizar, todo sale de caché.
        pendienteCliente.complete(_iconoPrueba(20, escala: 2.0));
        var seq = 21;
        for (final c in pendientesPin.values) {
          c.complete(_iconoPrueba(seq++, escala: 2.0));
        }
        await tester.pump();
        await tester.pumpWidget(construir(zoom: 15.5, seleccionadoId: 'n1'));

        expect(llamadasCliente, 1);
        expect(llamadasPin.values.every((v) => v == 1), isTrue);
      },
    );

    testWidgets(
      'F4 densidad y dispose: regenera al cambiar densidad, descarta obsoletos y limpia caché',
      (tester) async {
        final claveVista = GlobalKey<VistaGoogleMapState>();
        final pendiente1x = Completer<BitmapDescriptor>();
        final pendienteDispose = Completer<BitmapDescriptor>();
        final icono1x = _iconoPrueba(30, escala: 1.0);
        final icono2x = _iconoPrueba(31, escala: 2.0);
        final icono2xSel = _iconoPrueba(32, escala: 2.0);
        final escalasRecibidas = <double>[];
        var marcadoresActuales = <Marker>{};

        Widget construir({
          required double pixelRatio,
          required List<PinNegocioMapa> pines,
        }) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 640),
              devicePixelRatio: pixelRatio,
            ),
            child: VistaGoogleMap(
              key: claveVista,
              datos: DatosMapaCercanos(
                posicionCliente: (lat: 21.12, lng: -101.68),
                pines: pines,
                seleccionadoId: null,
                zoomInicial: 14,
                onSeleccionarPin: (_) {},
              ),
              generadorIconoCliente: ({required pixelRatio}) async =>
                  _iconoPrueba(33, escala: pixelRatio),
              generadorIconoPin:
                  ({
                    required etiqueta,
                    required seleccionado,
                    required pixelRatio,
                  }) {
                    escalasRecibidas.add(pixelRatio);
                    if (pixelRatio == 1.0 && !seleccionado) {
                      return pendiente1x.future;
                    }
                    if (etiqueta == '3.0 km') {
                      return pendienteDispose.future;
                    }
                    return Future.value(seleccionado ? icono2xSel : icono2x);
                  },
              constructorMapaNativo:
                  ({
                    required camaraInicial,
                    required marcadores,
                    required padding,
                    required onMapCreated,
                  }) {
                    marcadoresActuales = marcadores;
                    return const SizedBox.expand();
                  },
            ),
          ),
        );

        final pinesIniciales = [
          _pinPrueba(1, 0.8, lat: 21.125, lng: -101.681),
        ];
        await tester.pumpWidget(
          construir(pixelRatio: 1.0, pines: pinesIniciales),
        );

        // Cambia la densidad antes de que termine el icono de 1.0x.
        await tester.pumpWidget(
          construir(pixelRatio: 2.0, pines: pinesIniciales),
        );
        await tester.pump();

        expect(escalasRecibidas, containsAll(<double>[1.0, 2.0]));
        final marcador2x = _buscarMarcador(marcadoresActuales, 'negocio-n1');
        expect(marcador2x, isNotNull);
        expect(marcador2x!.icon, same(icono2x));

        // Si llega tarde la respuesta de 1.0x, no sobrescribe el icono de 2.0x.
        pendiente1x.complete(icono1x);
        await tester.pumpAndSettle();
        expect(
          _buscarMarcador(marcadoresActuales, 'negocio-n1')!.icon,
          same(icono2x),
        );

        final estado = claveVista.currentState!;
        expect(estado.entradasCacheParaPruebas, greaterThan(0));

        // Agregamos un pin pendiente y desmontamos la vista: debe limpiar caché
        // y no fallar si el futuro resuelve después de dispose.
        await tester.pumpWidget(
          construir(
            pixelRatio: 2.0,
            pines: [
              ...pinesIniciales,
              _pinPrueba(9, 3.0, lat: 21.14, lng: -101.67),
            ],
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(estado.entradasCacheParaPruebas, 0);

        pendienteDispose.complete(_iconoPrueba(39, escala: 2.0));
        await tester.pump();
        expect(estado.entradasCacheParaPruebas, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'F3 ciclo de vida: anima la cámara al seleccionar y libera el controlador en dispose',
      (tester) async {
        final controlador = _ControladorMapaFalso();
        var controladorEntregado = false;

        Widget construir(String? seleccionadoId) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              devicePixelRatio: 1.0,
            ),
            child: VistaGoogleMap(
              datos: DatosMapaCercanos(
                posicionCliente: (lat: 21.12, lng: -101.68),
                pines: [
                  _pinPrueba(
                    1,
                    0.8,
                    lat: 21.125,
                    lng: -101.681,
                    seleccionado: seleccionadoId == 'n1',
                  ),
                  _pinPrueba(
                    2,
                    1.5,
                    lat: 21.135,
                    lng: -101.675,
                    seleccionado: seleccionadoId == 'n2',
                  ),
                ],
                seleccionadoId: seleccionadoId,
                zoomInicial: 14,
                onSeleccionarPin: (_) {},
              ),
              generadorIconoCliente: ({required pixelRatio}) async =>
                  _iconoPrueba(40),
              generadorIconoPin:
                  ({
                    required etiqueta,
                    required seleccionado,
                    required pixelRatio,
                  }) async => _iconoPrueba(seleccionado ? 42 : 41),
              constructorMapaNativo:
                  ({
                    required camaraInicial,
                    required marcadores,
                    required padding,
                    required onMapCreated,
                  }) {
                    if (!controladorEntregado) {
                      controladorEntregado = true;
                      onMapCreated(controlador);
                    }
                    return const SizedBox.expand();
                  },
            ),
          ),
        );

        await tester.pumpWidget(construir(null));
        await tester.pumpAndSettle();
        expect(controlador.animaciones, isEmpty);

        await tester.pumpWidget(construir('n2'));
        expect(controlador.animaciones, hasLength(1));
        expect(controlador.animaciones.single.toJson(), [
          'newLatLng',
          [21.135, -101.675],
        ]);
        expect(controlador.desechado, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(controlador.desechado, isTrue);
      },
    );
  });
}
