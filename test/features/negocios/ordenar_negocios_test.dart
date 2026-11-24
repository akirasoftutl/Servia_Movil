import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/data/orden_negocios.dart';
import 'package:servia/features/negocios/mensajes.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';
import 'utilidades_prueba.dart';

/// Doble de `GET /negocios` y `GET /categorias` con el JSON real de la API
/// (Servia_BE#110): `{ items: [...], siguiente }`. Como la API real, el cursor
/// solo vale con el orden con el que se obtuvo: si no coincide responde 400.
class ApiFalsa {
  static const total = 45;
  static const tamanoPagina = 20;

  /// `n00` es el más antiguo y `n44` el más reciente; por nombre, `n00` va primero.
  static final ids = List.generate(
    total,
    (i) => 'n${i.toString().padLeft(2, '0')}',
  );

  final peticiones = <Uri>[];

  /// `GET /negocios` es público: ninguna petición debe llevar token.
  bool conToken = false;
  Future<http.Response>? Function(Uri url)? interceptar;

  Uri get ultima => peticiones.last;
  List<Uri> get listados =>
      peticiones.where((u) => u.path == '/negocios').toList();

  NegociosService get service => NegociosService(
    api: ApiClient(
      client: MockClient((r) async {
        peticiones.add(r.url);
        conToken |= r.headers.containsKey('Authorization');
        final propia = interceptar?.call(r.url);
        if (propia != null) return propia;
        if (r.url.path == '/categorias') {
          return http.Response(
            jsonEncode([
              {
                'id': 'cabello',
                'nombre': 'Cabello y barba',
                'orden': 1,
                'activo': true,
              },
            ]),
            200,
          );
        }
        return _listar(r.url.queryParameters);
      }),
    ),
  );

  http.Response _listar(Map<String, String> query) {
    final recientes = query['orden'] == 'recientes';
    if (query['orden'] != null && !recientes) {
      return http.Response(
        jsonEncode({
          'message': ['El orden debe ser nombre o recientes.'],
        }),
        400,
      );
    }
    final ordenados = recientes ? ids.reversed.toList() : ids;
    var inicio = 0;
    final cursor = query['cursor'];
    if (cursor != null) {
      final partes = cursor.split(':');
      final indice = partes.length == 2 ? ordenados.indexOf(partes[1]) : -1;
      if (partes[0] != (recientes ? 'recientes' : 'nombre') || indice < 0) {
        return http.Response(
          jsonEncode({
            'message':
                'El cursor no corresponde a un negocio visible existente.',
          }),
          400,
        );
      }
      inicio = indice + 1;
    }
    final fin = (inicio + tamanoPagina).clamp(0, total).toInt();
    final pagina = ordenados.sublist(inicio, fin);
    return http.Response(
      jsonEncode({
        'items': [
          for (final id in pagina)
            {
              'id': id,
              'nombre': 'Negocio $id',
              'categoriaId': 'cabello',
              'fotos': {'portada': null, 'galeria': []},
              'aceptaReservas': true,
            },
        ],
        'siguiente': fin < total
            ? '${recientes ? 'recientes' : 'nombre'}:${pagina.last}'
            : null,
      }),
      200,
    );
  }
}

Future<void> abrirConApi(WidgetTester tester, ApiFalsa api) async {
  // Viewport alto: se construyen la cuadrícula y las listas de la portada.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: ListaNegociosPage(negociosService: api.service)),
  );
  await tester.pumpAndSettle();
}

/// Con una petición en vuelo hay un indicador de carga animado y
/// `pumpAndSettle` no termina: ahí se avanza el tiempo a mano.
Future<void> elegirOrden(
  WidgetTester tester,
  String etiqueta, {
  bool esperar = true,
}) async {
  Future<void> avanzar() => esperar
      ? tester.pumpAndSettle()
      : tester.pump(const Duration(milliseconds: 400));
  await tester.tap(find.byType(DropdownButton<OrdenNegocios>));
  await avanzar();
  await tester.tap(find.text(etiqueta).last);
  await avanzar();
}

/// Baja hasta el final de la lista hasta que ya no hay más páginas.
Future<void> cargarTodasLasPaginas(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await desplazarListaAlFinal(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('NegociosService.listarNegocios', () {
    Future<Uri> pedir(Future<void> Function(NegociosService) accion) async {
      final api = ApiFalsa();
      await accion(api.service);
      return api.ultima;
    }

    test('sin orden no manda el parámetro (A-Z por omisión)', () async {
      final url = await pedir((s) async => s.listarNegocios());
      expect(url.queryParameters, {'limite': '20'});
    });

    test('con Nombre (A-Z) tampoco manda el parámetro', () async {
      final url = await pedir(
        (s) async => s.listarNegocios(orden: OrdenNegocios.nombre),
      );
      expect(url.queryParameters, {'limite': '20'});
    });

    test('con Más recientes manda orden=recientes', () async {
      final url = await pedir(
        (s) async => s.listarNegocios(orden: OrdenNegocios.recientes),
      );
      expect(url.path, '/negocios');
      expect(url.queryParameters, {'limite': '20', 'orden': 'recientes'});
    });

    test('el orden viaja junto con cursor, texto y categoría', () async {
      final url = await pedir(
        (s) async => s.listarNegocios(
          orden: OrdenNegocios.recientes,
          cursor: 'recientes:n40',
          q: 'corte',
          categoriaId: 'cabello',
        ),
      );
      expect(url.queryParameters, {
        'limite': '20',
        'orden': 'recientes',
        'cursor': 'recientes:n40',
        'q': 'corte',
        'categoriaId': 'cabello',
      });
    });

    test('lee la página real: más recientes primero', () async {
      final api = ApiFalsa();
      final pagina = await api.service.listarNegocios(
        orden: OrdenNegocios.recientes,
      );
      expect(pagina.items.first.id, 'n44');
      expect(pagina.items, hasLength(20));
      expect(pagina.siguiente, 'recientes:n25');
      final az = await api.service.listarNegocios();
      expect(az.items.first.id, 'n00');
    });

    test('un cursor de otro orden se rechaza con 400 (contrato)', () async {
      final api = ApiFalsa();
      await expectLater(
        api.service.listarNegocios(
          orden: OrdenNegocios.recientes,
          cursor: 'nombre:n19',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'estado', 400)),
      );
    });
  });

  group('OrdenNegocios', () {
    test('las etiquetas están en español', () {
      expect(OrdenNegocios.nombre.etiqueta, 'Nombre (A-Z)');
      expect(OrdenNegocios.recientes.etiqueta, 'Más recientes');
      expect(OrdenNegocios.values, hasLength(2));
    });
  });

  group('selector de orden en la lista', () {
    testWidgets('ofrece Nombre (A-Z) por omisión y Más recientes', (
      tester,
    ) async {
      final api = ApiFalsa();
      await abrirConApi(tester, api);
      expect(find.text(MensajesNegocios.ordenarPor), findsOneWidget);
      expect(find.text(MensajesNegocios.ordenNombre), findsOneWidget);
      expect(find.text(MensajesNegocios.ordenRecientes), findsNothing);
      await tester.tap(find.byType(DropdownButton<OrdenNegocios>));
      await tester.pumpAndSettle();
      expect(find.text(MensajesNegocios.ordenNombre), findsWidgets);
      expect(find.text(MensajesNegocios.ordenRecientes), findsOneWidget);
      // La primera carga se comporta como hoy: sin parámetro `orden`.
      expect(api.listados.single.queryParameters, {'limite': '20'});
    });

    testWidgets('Más recientes pide la primera página sin cursor', (
      tester,
    ) async {
      final api = ApiFalsa();
      await abrirConApi(tester, api);
      final antes = api.listados.length;
      await elegirOrden(tester, MensajesNegocios.ordenRecientes);
      expect(api.listados[antes].queryParameters, {
        'limite': '20',
        'orden': 'recientes',
      });
      expect(find.text('Negocio n44'), findsWidgets);
      expect(find.text('Negocio n00', skipOffstage: false), findsNothing);
      expect(api.conToken, false);
    });

    testWidgets('el orden se conserva al paginar, sin 400 ni repetidos', (
      tester,
    ) async {
      final api = ApiFalsa();
      await abrirConApi(tester, api);
      final antes = api.listados.length;
      await elegirOrden(tester, MensajesNegocios.ordenRecientes);
      await cargarTodasLasPaginas(tester);
      final pedidas = api.listados.sublist(antes);
      expect(pedidas.map((u) => u.queryParameters['cursor']), [
        null,
        'recientes:n25',
        'recientes:n05',
      ]);
      expect(pedidas.map((u) => u.queryParameters['orden']).toSet(), {
        'recientes',
      });
      expect(find.text(MensajesNegocios.errorApi), findsNothing);
      expect(find.text(MensajesNegocios.busquedaInvalida), findsNothing);
      // Las 45 tarjetas de «Lugares cercanos» (15 px): ni omitida ni repetida.
      final tarjetas = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  w.style?.fontSize == 15 &&
                  (w.data ?? '').startsWith('Negocio n'),
              skipOffstage: false,
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(tarjetas, [for (final id in ApiFalsa.ids.reversed) 'Negocio $id']);
    });

    testWidgets(
      'al cambiar de orden a mitad de la lista reinicia cursor y scroll',
      (tester) async {
        final api = ApiFalsa();
        await abrirConApi(tester, api);
        await desplazarListaAlFinal(tester);
        await tester.pumpAndSettle();
        final controller = tester.widget<ListView>(listaVertical()).controller!;
        expect(controller.offset, greaterThan(0));
        expect(api.listados.last.queryParameters['cursor'], 'nombre:n19');
        final antes = api.listados.length;
        await elegirOrden(tester, MensajesNegocios.ordenRecientes);
        expect(api.listados[antes].queryParameters, {
          'limite': '20',
          'orden': 'recientes',
        });
        expect(tester.widget<ListView>(listaVertical()).controller!.offset, 0);
        // La lista anterior ya no se mezcla con la nueva.
        expect(find.text('Negocio n00', skipOffstage: false), findsNothing);
      },
    );

    testWidgets('el orden sobrevive a la búsqueda y a la categoría', (
      tester,
    ) async {
      final api = ApiFalsa();
      await abrirConApi(tester, api);
      await elegirOrden(tester, MensajesNegocios.ordenRecientes);
      var antes = api.listados.length;
      await elegirCategoria(tester, 'Cabello y barba');
      expect(api.listados[antes].queryParameters, {
        'limite': '20',
        'orden': 'recientes',
        'categoriaId': 'cabello',
      });
      antes = api.listados.length;
      await tester.enterText(find.byType(TextField), 'corte');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(api.listados[antes].queryParameters, {
        'limite': '20',
        'orden': 'recientes',
        'categoriaId': 'cabello',
        'q': 'corte',
      });
      // Con búsqueda activa el selector sigue ahí y conserva la elección.
      expect(find.text(MensajesNegocios.ordenRecientes), findsOneWidget);
    });

    testWidgets('cambiar el orden con búsqueda activa conserva q y categoría', (
      tester,
    ) async {
      final api = ApiFalsa();
      await abrirConApi(tester, api);
      await elegirCategoria(tester, 'Cabello y barba');
      await tester.enterText(find.byType(TextField), 'corte');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final antes = api.listados.length;
      await elegirOrden(tester, MensajesNegocios.ordenRecientes);
      expect(api.listados[antes].queryParameters, {
        'limite': '20',
        'orden': 'recientes',
        'categoriaId': 'cabello',
        'q': 'corte',
      });
    });

    testWidgets('volver a Nombre (A-Z) no manda el parámetro orden', (
      tester,
    ) async {
      final api = ApiFalsa();
      await abrirConApi(tester, api);
      await elegirOrden(tester, MensajesNegocios.ordenRecientes);
      final antes = api.listados.length;
      await elegirOrden(tester, MensajesNegocios.ordenNombre);
      expect(api.listados[antes].queryParameters, {'limite': '20'});
      expect(find.text('Negocio n00'), findsWidgets);
    });

    testWidgets('elegir el orden que ya está activo no vuelve a pedir', (
      tester,
    ) async {
      final api = ApiFalsa();
      await abrirConApi(tester, api);
      final antes = api.listados.length;
      await elegirOrden(tester, MensajesNegocios.ordenNombre);
      expect(api.listados, hasLength(antes));
    });

    testWidgets('un error al cambiar el orden se muestra con Reintentar', (
      tester,
    ) async {
      final api = ApiFalsa();
      await abrirConApi(tester, api);
      var falla = true;
      api.interceptar = (url) => falla && url.path == '/negocios'
          ? Future.value(http.Response('{"message":"x"}', 503))
          : null;
      await elegirOrden(tester, MensajesNegocios.ordenRecientes);
      expect(find.text(MensajesNegocios.errorApi), findsOneWidget);
      // El selector sigue disponible durante el error.
      expect(find.text(MensajesNegocios.ordenRecientes), findsOneWidget);
      falla = false;
      final antes = api.listados.length;
      await tester.tap(find.text(MensajesNegocios.reintentar));
      await tester.pumpAndSettle();
      expect(api.listados[antes].queryParameters, {
        'limite': '20',
        'orden': 'recientes',
      });
      expect(find.text('Negocio n44'), findsWidgets);
    });

    testWidgets('el 400 por orden inválido no ofrece reintentar', (
      tester,
    ) async {
      final api = ApiFalsa();
      await abrirConApi(tester, api);
      api.interceptar = (url) => url.path == '/negocios'
          ? Future.value(
              http.Response(
                jsonEncode({
                  'message': ['El orden debe ser nombre o recientes.'],
                }),
                400,
              ),
            )
          : null;
      await elegirOrden(tester, MensajesNegocios.ordenRecientes);
      expect(find.text(MensajesNegocios.busquedaInvalida), findsOneWidget);
      expect(find.text(MensajesNegocios.reintentar), findsNothing);
    });

    testWidgets('sin negocios con Más recientes muestra el estado vacío', (
      tester,
    ) async {
      final api = ApiFalsa();
      await abrirConApi(tester, api);
      api.interceptar = (url) => url.path == '/negocios'
          ? Future.value(http.Response('{"items":[],"siguiente":null}', 200))
          : null;
      await elegirOrden(tester, MensajesNegocios.ordenRecientes);
      expect(find.text(MensajesNegocios.listaVacia), findsOneWidget);
      expect(find.text(MensajesNegocios.ordenRecientes), findsOneWidget);
    });
  });

  group('carreras y continuación con dobles del servicio', () {
    testWidgets('una página anterior que llega tarde no pisa el nuevo orden', (
      tester,
    ) async {
      final vieja = Completer<PaginaNegocios>();
      final fake = ListaServiceFalso();
      fake.responder = (cursor) async {
        if (fake.ordenes.last == OrdenNegocios.recientes) {
          return pagina([resumen('nuevo')]);
        }
        return cursor == null ? pagina([resumen('az')], 'dos') : vieja.future;
      };
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: ListaNegociosPage(negociosService: fake)),
      );
      await tester.pump();
      await tester.pump();
      // La lista es corta: la segunda página A-Z queda en vuelo...
      expect(fake.llamadas, [null, 'dos']);
      // ...y el usuario cambia el orden antes de que llegue.
      await elegirOrden(
        tester,
        MensajesNegocios.ordenRecientes,
        esperar: false,
      );
      expect(fake.llamadas, [null, 'dos', null]);
      expect(fake.ordenes.last, OrdenNegocios.recientes);
      vieja.complete(pagina([resumen('viejo')]));
      await tester.pumpAndSettle();
      expect(find.text('Negocio nuevo', skipOffstage: false), findsWidgets);
      expect(find.text('Negocio viejo', skipOffstage: false), findsNothing);
      expect(find.text('Negocio az', skipOffstage: false), findsNothing);
    });

    testWidgets('la primera página vieja tampoco pisa al nuevo orden', (
      tester,
    ) async {
      final vieja = Completer<PaginaNegocios>();
      final fake = ListaServiceFalso();
      var primera = true;
      fake.responder = (_) {
        if (primera) {
          primera = false;
          return vieja.future;
        }
        return Future.value(pagina([resumen('nuevo')]));
      };
      await tester.pumpWidget(
        MaterialApp(home: ListaNegociosPage(negociosService: fake)),
      );
      await tester.pump();
      await elegirOrden(
        tester,
        MensajesNegocios.ordenRecientes,
        esperar: false,
      );
      vieja.complete(pagina([resumen('viejo')]));
      await tester.pumpAndSettle();
      expect(find.text('Negocio nuevo', skipOffstage: false), findsWidgets);
      expect(find.text('Negocio viejo', skipOffstage: false), findsNothing);
    });

    testWidgets('las páginas vacías con continuación mandan siempre el orden', (
      tester,
    ) async {
      final fake = ListaServiceFalso();
      // Con varias palabras en la búsqueda las páginas vienen vacías con `siguiente`.
      var vacias = 0;
      fake.responder = (cursor) async {
        if (fake.ordenes.last == OrdenNegocios.nombre) {
          return pagina([resumen('inicial')]);
        }
        if (cursor == null || vacias < 2) {
          vacias++;
          return pagina([], 'c$vacias');
        }
        return pagina([resumen('hallado')]);
      };
      await tester.pumpWidget(
        MaterialApp(home: ListaNegociosPage(negociosService: fake)),
      );
      await tester.pumpAndSettle();
      await elegirOrden(tester, MensajesNegocios.ordenRecientes);
      expect(fake.llamadas.sublist(1), [null, 'c1', 'c2']);
      expect(fake.ordenes.sublist(1).toSet(), {OrdenNegocios.recientes});
      expect(find.text('Negocio hallado', skipOffstage: false), findsWidgets);
    });
  });
}
