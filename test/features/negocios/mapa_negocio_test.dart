import 'dart:async';
import 'dart:convert' show base64, jsonEncode;
import 'dart:io';
import 'dart:ui' show Codec;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/features/negocios/data/negocio.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/fotos_negocio.dart';
import 'package:servia/features/negocios/pages/mapa_negocio.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import 'datos_prueba.dart';

final _png = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
);

class ImagenPendiente extends ImageProvider<ImagenPendiente> {
  final codec = Completer<Codec>();
  @override
  Future<ImagenPendiente> obtainKey(ImageConfiguration configuration) async =>
      this;
  @override
  ImageStreamCompleter loadBuffer(
    ImagenPendiente key,
    DecoderBufferCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: codec.future, scale: 1);
}

Future<void> perfil(
  WidgetTester tester, {
  Object? ubicacion = const {'lat': 21.1, 'lng': -101.7},
  ProveedorImagenNegocio? imagen,
  LanzadorRutaNegocio? lanzar,
  bool esperar = true,
}) async {
  final datos = negocioJson()..['ubicacion'] = ubicacion;
  final api = ApiClient(
    client: MockClient((peticion) async {
      expect(peticion.headers.containsKey('authorization'), isFalse);
      switch (peticion.url.path) {
        case '/negocios/abc123':
          return http.Response(jsonEncode(datos), 200);
        case '/categorias':
          return http.Response('[]', 200);
        case '/negocios/abc123/servicios':
          return http.Response('[]', 200);
        default:
          throw StateError('Petición inesperada');
      }
    }),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: PerfilNegocioPage(
        negocioId: 'abc123',
        negociosService: NegociosService(api: api),
        proveedorMapa: imagen ?? (_) => MemoryImage(_png),
        lanzadorRuta: lanzar ?? (_) async => true,
      ),
    ),
  );
  if (esperar) {
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(_png),
        tester.element(find.byType(PerfilNegocioPage)),
      ),
    );
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'con ubicación: mapa público accesible después del contacto y botón',
    (tester) async {
      final urls = <String>[];
      await perfil(
        tester,
        imagen: (url) {
          urls.add(url);
          return MemoryImage(_png);
        },
      );
      expect(urls, ['${ApiClient.baseUrl}/negocios/abc123/mapa']);
      expect(find.byType(MapaNegocio), findsOneWidget);
      expect(find.text(MensajesNegocios.ubicacion), findsOneWidget);
      expect(
        find.bySemanticsLabel(MensajesNegocios.descripcionMapa),
        findsOneWidget,
      );
      expect(find.text(MensajesNegocios.comoLlegar), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(MapaNegocio)).dy,
        greaterThan(tester.getTopLeft(find.text('4771234567')).dy),
      );
      final imagen = tester.widget<Image>(find.byType(Image));
      expect(imagen.image, isA<MemoryImage>());
      expect(find.text('Horario de atención'), findsOneWidget);
      expect(find.text('Servicios'), findsOneWidget);
    },
  );

  testWidgets('ruta: lanza destino correcto sin origen del cliente', (
    tester,
  ) async {
    Uri? ruta;
    await perfil(
      tester,
      lanzar: (uri) async {
        ruta = uri;
        return true;
      },
    );
    await tester.ensureVisible(find.text(MensajesNegocios.comoLlegar));
    await tester.tap(find.text(MensajesNegocios.comoLlegar));
    await tester.pumpAndSettle();
    expect(ruta!.scheme, 'https');
    expect(ruta!.host, 'www.google.com');
    expect(ruta!.path, '/maps/dir/');
    expect(ruta!.queryParameters, {'api': '1', 'destination': '21.1,-101.7'});
    expect(find.text(MensajesNegocios.errorAppMapas), findsNothing);
  });

  testWidgets(
    'sin ubicación: no hay sección ni botón y conserva contacto y servicios',
    (tester) async {
      await perfil(
        tester,
        ubicacion: null,
        imagen: (_) => throw StateError('No debe pedir imagen'),
      );
      expect(find.byType(MapaNegocio), findsNothing);
      expect(find.text(MensajesNegocios.ubicacion), findsNothing);
      expect(find.text(MensajesNegocios.comoLlegar), findsNothing);
      expect(find.text('4771234567'), findsOneWidget);
      expect(
        find.text('Calle Luna 12, Col. Centro, 37000, León, Guanajuato'),
        findsOneWidget,
      );
      expect(find.text('Horario de atención'), findsOneWidget);
      expect(find.text('Servicios'), findsOneWidget);
    },
  );

  test(
    'modelo tolera ubicación ausente o malformada y admite cero y enteros',
    () {
      expect(Negocio.fromJson(negocioJson()).ubicacion, isNull);
      for (final valor in [
        null,
        '21,-101',
        [],
        {},
        {'lat': 21},
        {'lat': '21', 'lng': -101},
        {'lat': 91, 'lng': 0},
        {'lat': 0, 'lng': 181},
        {'lat': double.nan, 'lng': 0},
        {'lat': 0, 'lng': double.infinity},
      ]) {
        expect(
          Negocio.fromJson(negocioJson()..['ubicacion'] = valor).ubicacion,
          isNull,
        );
      }
      final ubicacion = Negocio.fromJson(
        negocioJson()..['ubicacion'] = {'lat': 0, 'lng': -101},
      ).ubicacion!;
      expect(ubicacion.lat, 0);
      expect(ubicacion.lng, -101);
    },
  );

  testWidgets('error de imagen: mensaje y perfil usable con ruta disponible', (
    tester,
  ) async {
    final imagen = ImagenPendiente();
    await perfil(tester, imagen: (_) => imagen, esperar: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    imagen.codec.completeError(StateError('Mapa no disponible'));
    await tester.pumpAndSettle();
    expect(find.text(MensajesNegocios.errorMapa), findsOneWidget);
    expect(find.text('Servicios'), findsOneWidget);
    expect(find.text('Horario de atención'), findsOneWidget);
    await tester.ensureVisible(find.text(MensajesNegocios.comoLlegar));
    await tester.tap(find.text(MensajesNegocios.comoLlegar));
    await tester.pumpAndSettle();
    expect(find.text(MensajesNegocios.errorAppMapas), findsNothing);
  });

  for (final falla in ['sin app', 'excepción']) {
    testWidgets('$falla: muestra aviso sin romper perfil', (tester) async {
      await perfil(
        tester,
        lanzar: (_) async {
          if (falla == 'excepción') throw PlatformException(code: 'sin_app');
          return false;
        },
      );
      await tester.ensureVisible(find.text(MensajesNegocios.comoLlegar));
      await tester.tap(find.text(MensajesNegocios.comoLlegar));
      await tester.pump();
      expect(find.text(MensajesNegocios.errorAppMapas), findsOneWidget);
      expect(find.byType(PerfilNegocioPage), findsOneWidget);
    });
  }

  test(
    'lanzador predeterminado usa aplicación externa mediante canal simulado',
    () async {
      MethodCall? llamada;
      const canal = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (call) async {
            llamada = call;
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(canal, null),
      );
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=21.1,-101.7',
      );
      expect(await abrirRutaNegocio(uri), isTrue);
      expect(llamada!.method, 'launch');
      expect(llamada!.arguments['url'], uri.toString());
      expect(llamada!.arguments['useSafariVC'], isFalse);
      expect(llamada!.arguments['useWebView'], isFalse);
      expect(llamada!.arguments['headers'], isEmpty);
    },
  );

  test(
    'sin SDK ni llave de mapas: imagen de API y dependencia url_launcher',
    () {
      final dependencias = File('pubspec.yaml').readAsStringSync();
      expect(dependencias, contains('url_launcher:'));
      expect(dependencias, isNot(matches(r'google_maps|flutter_map|maps_sdk')));
      final mapa = File('lib/features/negocios/pages/mapa_negocio.dart')
          .readAsStringSync();
      expect(mapa, contains('ApiClient.baseUrl'));
      expect(mapa, isNot(matches(r'maps.googleapis.com|AIza|apiKey|[?&]key=')));
      final proveedor = const PerfilNegocioPage(negocioId: 'abc123')
          .proveedorMapa;
      expect(
        (proveedor('https://api.test/mapa') as NetworkImage).headers,
        isNull,
      );
    },
  );
}
