import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:servia/core/network/api_client.dart';
import 'package:servia/features/negocios/data/negocios_service.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';

import 'datos_prueba.dart';

void main() {
  testWidgets(
    'el perfil consulta y muestra sus servicios después del horario',
    (tester) async {
      final rutas = <String>[];
      final service = NegociosService(
        api: ApiClient(
          client: MockClient((request) async {
            rutas.add(request.url.path);
            final Object respuesta;
            switch (request.url.path) {
              case '/negocios/abc123':
                respuesta = negocioJson();
              case '/categorias':
                respuesta = [];
              case '/negocios/abc123/servicios':
                respuesta = [
                  {
                    'id': 'corte',
                    'nombre': 'Corte activo',
                    'precio': 150,
                    'duracionMin': 30,
                  },
                ];
              default:
                throw StateError('Ruta inesperada: ${request.url.path}');
            }
            return http.Response(jsonEncode(respuesta), 200);
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilNegocioPage(
            negocioId: 'abc123',
            negociosService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rutas.where((r) => r.endsWith('/servicios')), [
        '/negocios/abc123/servicios',
      ]);
      expect(find.text('Servicios'), findsOneWidget);
      expect(find.text('Corte activo'), findsOneWidget);
      expect(find.text(r'$150'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Servicios')).dy,
        greaterThan(tester.getTopLeft(find.text('Domingo')).dy),
      );
    },
  );
}
