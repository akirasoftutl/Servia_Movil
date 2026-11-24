import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/features/negocios/data/negocio_cercano.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

import 'fakes.dart';

/// Elemento de `NegocioPublicoDto`: `categoriaId` es `string | null`.
Map<String, Object?> publico(String id, {String? categoriaId = 'cabello'}) => {
  'id': id,
  'nombre': 'Negocio $id',
  'categoriaId': categoriaId,
  'fotos': {'portada': null, 'galeria': <Object>[]},
  'aceptaReservas': true,
};

Map<String, Object?> cercanoPublico(String id, {String? categoriaId}) => {
  ...publico(id, categoriaId: categoriaId),
  'distanciaKm': 1.2,
};

NegociosService servicio(Object cuerpo) => NegociosService(
  api: ApiClient(
    client: MockClient((_) async => http.Response(jsonEncode(cuerpo), 200)),
  ),
);

void main() {
  test('NegocioResumen acepta categoriaId null y conserva el resto', () {
    final negocio = NegocioResumen.fromJson(publico('n1', categoriaId: null));
    expect(negocio.categoriaId, isNull);
    expect(negocio.nombre, 'Negocio n1');
    expect(negocio.imagenUrl, isNull);
  });

  test('NegocioResumen rechaza un categoriaId que no sea texto ni null', () {
    final json = publico('n1')..['categoriaId'] = 7;
    expect(() => NegocioResumen.fromJson(json), throwsFormatException);
  });

  test('GET /negocios: un negocio sin categoría no rompe la página', () async {
    final pagina = await servicio({
      'items': [
        publico('a'),
        publico('b', categoriaId: null),
        publico('c', categoriaId: 'uñas'),
      ],
      'siguiente': null,
    }).listarNegocios();
    expect(pagina.items.map((n) => n.id), ['a', 'b', 'c']);
    expect(pagina.items.map((n) => n.categoriaId), ['cabello', null, 'uñas']);
  });

  test(
    'GET /negocios/cercanos: un negocio sin categoría no rompe la lista',
    () async {
      final lista = await servicio({
        'items': [
          cercanoPublico('a', categoriaId: 'cabello'),
          cercanoPublico('b'),
          cercanoPublico('c', categoriaId: 'uñas'),
        ],
      }).obtenerCercanos(lat: 21.1, lng: -101.6);
      expect(lista.map((n) => n.negocio.id), ['a', 'b', 'c']);
      expect(lista[1].negocio.categoriaId, isNull);
      expect(lista[1].distanciaKm, 1.2);
    },
  );

  test('NegocioCercano acepta categoriaId null', () {
    expect(
      NegocioCercano.fromJson(cercanoPublico('x')).negocio.categoriaId,
      isNull,
    );
  });

  testWidgets('la lista muestra un negocio sin categoría junto a los demás', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = ListaServiceFalso();
    fake.responder = (_) async => PaginaNegocios.fromJson({
      'items': [publico('a'), publico('b', categoriaId: null), publico('c')],
      'siguiente': null,
    });
    await tester.pumpWidget(
      MaterialApp(home: ListaNegociosPage(negociosService: fake)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Negocio a'), findsWidgets);
    expect(find.text('Negocio b'), findsWidgets);
    expect(find.text('Negocio c'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
