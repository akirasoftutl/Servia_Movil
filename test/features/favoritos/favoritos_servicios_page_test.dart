import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/widgets/estados.dart';
import 'package:servia/features/favoritos/data/favoritos_controlador.dart';
import 'package:servia/features/favoritos/data/favoritos_servicios_controlador.dart';
import 'package:servia/features/favoritos/mensajes.dart';
import 'package:servia/features/favoritos/pages/favoritos_page.dart';
import 'package:servia/features/favoritos/pages/tarjeta_servicio_favorito.dart';
import 'package:servia/features/negocios/pages/detalle_servicio_page.dart';
import 'package:servia/features/negocios/pages/tarjeta_negocio.dart';

import '../negocios/fakes.dart';
import 'fakes_favoritos.dart';

late DetalleServiceFalso negociosFalso;

Future<void> abrir(
  WidgetTester tester,
  FavoritosControlador negocios,
  FavoritosServiciosControlador servicios,
) async {
  negociosFalso = DetalleServiceFalso();
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      home: FavoritosPage(
        controlador: negocios,
        serviciosControlador: servicios,
        negociosService: negociosFalso,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> irAServicios(WidgetTester tester) async {
  await tester.tap(find.text(MensajesFavoritos.tabServicios));
  await tester.pumpAndSettle();
}

void main() {
  late ApiFavoritosFalsa api;
  late SesionFavoritos sesion;
  late FavoritosControlador negocios;
  late FavoritosServiciosControlador servicios;

  setUp(() {
    api = ApiFavoritosFalsa();
    sesion = SesionFavoritos('ana');
    negocios = api.controlador(sesion);
    servicios = api.controladorServicios(sesion);
  });

  testWidgets('hay dos pestañas, «Negocios» (la de siempre) y «Servicios»', (
    tester,
  ) async {
    api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
    await abrir(tester, negocios, servicios);

    expect(find.text(MensajesFavoritos.tabNegocios), findsOneWidget);
    expect(find.text(MensajesFavoritos.tabServicios), findsOneWidget);
    expect(find.text('Negocios'), findsOneWidget);
    expect(find.text('Servicios'), findsOneWidget);
    // Abre en Negocios, como antes.
    expect(find.byType(TarjetaNegocio), findsOneWidget);
    expect(find.text('Spa Aurora'), findsOneWidget);
  });

  testWidgets('las pestañas no mezclan negocios con servicios', (tester) async {
    api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
    api
        .serviciosDe('ana')
        .add(servicioFavorito('b1', 's1', nombre: 'Masaje relajante'));
    await abrir(tester, negocios, servicios);
    expect(find.text('Spa Aurora'), findsOneWidget);
    expect(find.text('Masaje relajante'), findsNothing);

    await irAServicios(tester);

    expect(find.byType(TarjetaServicioFavorito), findsOneWidget);
    expect(find.text('Masaje relajante'), findsOneWidget);
    expect(find.byType(TarjetaNegocio), findsNothing);
  });

  testWidgets('la lista de servicios solo se consulta al abrir su pestaña', (
    tester,
  ) async {
    await abrir(tester, negocios, servicios);
    expect(api.metodos(), ['GET /favoritos/negocios']);

    await irAServicios(tester);
    expect(api.metodos(), [
      'GET /favoritos/negocios',
      'GET /favoritos/servicios',
    ]);
  });

  testWidgets(
    'muestra nombre, negocio, precio y duración, del más reciente al más antiguo',
    (tester) async {
      api.serviciosDe('ana').addAll([
        servicioFavorito(
          'n2',
          's9',
          nombre: 'Corte clásico',
          negocioNombre: 'Barbería Luna',
          precio: 150.5,
          duracionMin: 90,
        ),
        servicioFavorito('n1', 's1', nombre: 'Masaje', precio: 200),
      ]);
      api.serviciosDe('beto').add(servicioFavorito('x', 'y', nombre: 'Ajeno'));
      await abrir(tester, negocios, servicios);
      await irAServicios(tester);

      expect(find.byType(TarjetaServicioFavorito), findsNWidgets(2));
      expect(find.text('Ajeno'), findsNothing);
      expect(find.text('Barbería Luna'), findsOneWidget);
      expect(find.text(r'$150.50'), findsOneWidget);
      expect(find.text('1 h 30 min'), findsOneWidget);
      expect(find.text(r'$200'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Corte clásico')).dy,
        lessThan(tester.getTopLeft(find.text('Masaje')).dy),
      );
    },
  );

  testWidgets(
    'cargando, y sin servicios: «Todavía no tienes servicios favoritos.»',
    (tester) async {
      await abrir(tester, negocios, servicios);
      api.retener = Completer<void>();
      await tester.tap(find.text('Servicios'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(EstadoCargando), findsOneWidget);

      api.retener!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(EstadoVacio), findsOneWidget);
      expect(
        find.text('Todavía no tienes servicios favoritos.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'error: «No se pudieron cargar tus favoritos.» y Reintentar recarga',
    (tester) async {
      api.erroresServicios['GET'] = (codigo: 500, mensaje: 'Falló');
      await abrir(tester, negocios, servicios);
      await irAServicios(tester);
      expect(find.byType(EstadoError), findsOneWidget);
      expect(find.text('No se pudieron cargar tus favoritos.'), findsOneWidget);

      api.erroresServicios.clear();
      api
          .serviciosDe('ana')
          .add(servicioFavorito('n1', 's1', nombre: 'Masaje'));
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byType(EstadoError), findsNothing);
      expect(find.text('Masaje'), findsOneWidget);
    },
  );

  testWidgets('un error en servicios no afecta a la pestaña de negocios', (
    tester,
  ) async {
    api.erroresServicios['GET'] = (codigo: 500, mensaje: 'Falló');
    api.de('ana').add(negocioFavorito('b1', nombre: 'Spa Aurora'));
    await abrir(tester, negocios, servicios);
    await irAServicios(tester);
    expect(find.byType(EstadoError), findsOneWidget);

    await tester.tap(find.text('Negocios'));
    await tester.pumpAndSettle();
    expect(find.text('Spa Aurora'), findsOneWidget);
    expect(find.byType(EstadoError), findsNothing);
  });

  testWidgets('sesión vencida (401): lo dice y no ofrece reintentar', (
    tester,
  ) async {
    api.erroresServicios['GET'] = (codigo: 401, mensaje: 'Unauthorized');
    await abrir(tester, negocios, servicios);
    await irAServicios(tester);
    expect(find.text(MensajesFavoritos.sesionVencida), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets(
    'tocar un servicio abre su detalle con los datos de la respuesta',
    (tester) async {
      api
          .serviciosDe('ana')
          .add(
            servicioFavorito(
              'abc123',
              's2',
              negocioNombre: 'Salón Aurora',
              aceptaReservas: false,
            ),
          );
      await abrir(tester, negocios, servicios);
      await irAServicios(tester);

      await tester.tap(find.byType(TarjetaServicioFavorito));
      await tester.pumpAndSettle();

      final detalle = tester.widget<DetalleServicioPage>(
        find.byType(DetalleServicioPage),
      );
      expect(detalle.negocioId, 'abc123');
      expect(detalle.servicioId, 's2');
      expect(detalle.aceptaReservas, isFalse);
      expect(detalle.negocioNombre, 'Salón Aurora');
      expect(negociosFalso.negocioConsultado, 'abc123');
      expect(negociosFalso.servicioConsultado, 's2');
    },
  );

  testWidgets(
    'quitar con el corazón lo saca de la lista sin recargar y al final queda el vacío',
    (tester) async {
      api.serviciosDe('ana').addAll([
        servicioFavorito('n1', 's2', nombre: 'Corte'),
        servicioFavorito('n1', 's1', nombre: 'Masaje'),
      ]);
      await abrir(tester, negocios, servicios);
      await irAServicios(tester);
      final consultas = api
          .metodos()
          .where((m) => m == 'GET /favoritos/servicios')
          .length;

      await tester.tap(find.byTooltip(MensajesFavoritos.quitar).first);
      await tester.pump();
      expect(find.text('Corte'), findsNothing);
      expect(find.text('Masaje'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(
        api.metodos().where((m) => m == 'GET /favoritos/servicios').length,
        consultas,
      );
      expect(api.serviciosDe('ana').map((s) => s['servicioId']), ['s1']);

      await tester.tap(find.byTooltip(MensajesFavoritos.quitar));
      await tester.pumpAndSettle();
      expect(
        find.text('Todavía no tienes servicios favoritos.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('si quitar falla, el servicio vuelve a la lista y se avisa', (
    tester,
  ) async {
    api.serviciosDe('ana').add(servicioFavorito('n1', 's1', nombre: 'Masaje'));
    await abrir(tester, negocios, servicios);
    await irAServicios(tester);
    api.erroresServicios['DELETE'] = (codigo: 500, mensaje: 'Falló');

    await tester.tap(find.byTooltip(MensajesFavoritos.quitar));
    await tester.pumpAndSettle();

    expect(find.text('Masaje'), findsOneWidget);
    expect(
      find.text('La API no está disponible. Intenta más tarde.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'los favoritos de negocios siguen funcionando igual en su pestaña',
    (tester) async {
      api.de('ana').addAll([
        negocioFavorito('b2', nombre: 'Barbería Luna'),
        negocioFavorito('b1', nombre: 'Spa Aurora'),
      ]);
      await abrir(tester, negocios, servicios);

      await tester.tap(find.byTooltip(MensajesFavoritos.quitar).first);
      await tester.pumpAndSettle();

      expect(find.text('Barbería Luna'), findsNothing);
      expect(api.metodos(), contains('DELETE /favoritos/negocios/b2'));
      expect(api.de('ana').map((n) => n['id']), ['b1']);
    },
  );

  testWidgets(
    'al entrar con otra cuenta no se ven los servicios de la anterior',
    (tester) async {
      api
          .serviciosDe('ana')
          .add(servicioFavorito('n1', 's1', nombre: 'Masaje'));
      await abrir(tester, negocios, servicios);
      await irAServicios(tester);
      expect(find.text('Masaje'), findsOneWidget);

      sesion.usuario = UsuarioFavoritos('beto');
      await abrir(tester, negocios, servicios);
      await irAServicios(tester);

      expect(find.text('Masaje'), findsNothing);
      expect(
        find.text('Todavía no tienes servicios favoritos.'),
        findsOneWidget,
      );
    },
  );
}
