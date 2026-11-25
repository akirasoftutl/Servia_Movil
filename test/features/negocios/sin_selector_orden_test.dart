import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';

/// El inicio ya no ofrece «Ordenar por»: los negocios salen con el orden por
/// omisión de la API (Nombre A-Z), que se obtiene sin mandar `orden`.
void main() {
  testWidgets('el inicio no muestra el selector y pide sin parámetro orden', (
    tester,
  ) async {
    final peticiones = <Uri>[];
    final service = NegociosService(
      api: ApiClient(
        client: MockClient((r) async {
          peticiones.add(r.url);
          if (r.url.path == '/negocios') {
            return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'n1',
                    'nombre': 'Negocio uno',
                    'categoriaId': 'cabello',
                    'aceptaReservas': true,
                  },
                ],
                'siguiente': null,
              }),
              200,
            );
          }
          return http.Response(
            r.url.path == '/categorias' ? '[]' : '{"items":[]}',
            200,
          );
        }),
      ),
    );
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: ListaNegociosPage(negociosService: service)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ordenar por'), findsNothing);
    expect(find.textContaining('Nombre (A-Z)'), findsNothing);
    expect(find.textContaining('Más recientes'), findsNothing);
    expect(find.byType(DropdownButton), findsNothing);
    expect(find.text('Negocio uno', skipOffstage: false), findsWidgets);
    final listados = peticiones.where((u) => u.path == '/negocios');
    expect(listados.single.queryParameters, {'limite': '20'});
  });
}
