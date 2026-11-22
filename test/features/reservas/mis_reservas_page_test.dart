import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/core/widgets/estados.dart';
import 'package:servia/features/reservas/data/reserva_resumen.dart';
import 'package:servia/features/reservas/pages/mis_reservas_page.dart';

import 'fakes.dart';

Future<void> abrir(WidgetTester tester, ReservasFalso reservas) async {
  final sesion = SesionFalsa();
  addTearDown(sesion.eventos.close);
  await tester.pumpWidget(
    MaterialApp(
      home: MisReservasPage(authService: sesion, reservasService: reservas),
      onGenerateRoute: (ajustes) => MaterialPageRoute<void>(
        settings: ajustes,
        builder: (_) => Scaffold(body: Text('Detalle ${ajustes.name}')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ReservasQueFallan extends ReservasFalso {
  bool fallar = true;

  @override
  Future<PaginaReservas> listarMias(
    String token, {
    String vista = 'proximas',
    String? cursor,
  }) async {
    vistas.add(vista);
    cursores.add(cursor);
    if (fallar) throw Exception('red');
    return PaginaReservas(items: [reservaResumen()], siguiente: null);
  }
}

void main() {
  testWidgets('muestra el título, las dos pestañas y consulta cada vista', (
    tester,
  ) async {
    final reservas = ReservasFalso(
      paginas: [
        PaginaReservas(items: [reservaResumen()], siguiente: null),
        PaginaReservas(
          items: [
            reservaResumen(
              id: 'r2',
              estado: 'completada',
              negocio: 'Salón Aurora',
              servicio: 'Tinte',
              inicio: DateTime.utc(2026, 10, 1, 19),
              fin: DateTime.utc(2026, 10, 1, 20),
            ),
          ],
          siguiente: null,
        ),
      ],
    );
    await abrir(tester, reservas);

    expect(find.text('Mis reservas'), findsOneWidget);
    expect(find.text('Próximas'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Barbería Central'), findsOneWidget);
    expect(find.text('Corte de cabello'), findsOneWidget);
    expect(reservas.vistas, ['proximas']);
    expect(reservas.tokens, ['token']);

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Salón Aurora'), findsOneWidget);
    expect(find.text('Tinte'), findsOneWidget);
    expect(reservas.vistas, ['proximas', 'historial']);

    // Volver a una pestaña ya cargada no repite la petición.
    await tester.tap(find.text('Próximas'));
    await tester.pumpAndSettle();
    expect(reservas.vistas, ['proximas', 'historial']);
  });

  testWidgets('la fecha y la hora se leen en America/Mexico_City', (
    tester,
  ) async {
    await abrir(
      tester,
      ReservasFalso(
        paginas: [
          PaginaReservas(
            items: [
              reservaResumen(inicio: DateTime.utc(2026, 11, 10, 16), fin: null),
            ],
            siguiente: null,
          ),
        ],
      ),
    );
    // 16:00 UTC son las 10:00 de México, aunque el teléfono esté en otra zona.
    // El rediseño muestra la fecha y la hora en dos Text separados.
    expect(find.text('martes 10 de noviembre de 2026'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('cada estado usa su texto y su tono', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final estados = [
      'pendiente',
      'confirmada',
      'rechazada',
      'rechazada_vencimiento',
      'cancelada',
      'completada',
    ];
    await abrir(
      tester,
      ReservasFalso(
        paginas: [
          PaginaReservas(
            items: [
              for (final estado in estados)
                reservaResumen(id: estado, estado: estado),
            ],
            siguiente: null,
          ),
        ],
      ),
    );
    for (final texto in [
      'Pendiente',
      'Confirmada',
      'Rechazada',
      'Rechazada por vencimiento',
      'Cancelada',
      'Completada',
    ]) {
      expect(find.text(texto), findsOneWidget);
    }
    // El badge ya no usa EtiquetaEstado: el tono se expresa con el color de
    // fondo del contenedor más cercano al texto, según _BadgeEstadoReserva.
    Color fondoDe(String texto) => (tester.widget<Container>(
          find.ancestor(
            of: find.text(texto),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color != null,
            ),
          ).first,
        ).decoration as BoxDecoration).color!;
    expect(fondoDe('Pendiente'), const Color(0xFFFEF3C7)); // aviso
    expect(fondoDe('Confirmada'), const Color(0xFFDCFCE7)); // éxito
    for (final neutro in [
      'Rechazada',
      'Rechazada por vencimiento',
      'Cancelada',
      'Completada',
    ]) {
      expect(fondoDe(neutro), const Color(0xFFF3F4F6));
    }
  });

  testWidgets('el vacío tiene un mensaje distinto en cada pestaña', (
    tester,
  ) async {
    await abrir(tester, ReservasFalso());
    expect(find.byType(EstadoVacio), findsOneWidget);
    expect(find.text('No tienes reservas próximas.'), findsOneWidget);

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.byType(EstadoVacio), findsOneWidget);
    expect(
      find.text('Todavía no tienes reservas en tu historial.'),
      findsOneWidget,
    );
  });

  testWidgets('un error de red muestra «Reintentar» y recupera la lista', (
    tester,
  ) async {
    final reservas = _ReservasQueFallan();
    await abrir(tester, reservas);
    expect(find.byType(EstadoError), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    reservas.fallar = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(reservas.vistas, ['proximas', 'proximas']);
    expect(find.byType(EstadoError), findsNothing);
    expect(find.text('Barbería Central'), findsOneWidget);
  });

  testWidgets('con 401 avisa de la sesión y no ofrece reintentar', (
    tester,
  ) async {
    await abrir(
      tester,
      ReservasFalso(errorListado: const ApiException(401, 'Sin sesión.')),
    );
    expect(
      find.text('Tu sesión ya no es válida. Inicia sesión de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsNothing);
  });

  testWidgets('«Cargar más» pide la siguiente página y añade sus tarjetas', (
    tester,
  ) async {
    final reservas = ReservasFalso(
      paginas: [
        PaginaReservas(
          items: [reservaResumen(folio: 'SRV-1')],
          siguiente: 'cursor-2',
        ),
        PaginaReservas(
          items: [
            reservaResumen(
              id: 'r2',
              folio: 'SRV-2',
              estado: 'confirmada',
              negocio: 'Salón Aurora',
            ),
          ],
          siguiente: null,
        ),
      ],
    );
    await abrir(tester, reservas);
    expect(find.text('Cargar más'), findsOneWidget);

    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();
    expect(reservas.cursores, [null, 'cursor-2']);
    expect(reservas.vistas, ['proximas', 'proximas']);
    expect(find.text('Barbería Central'), findsOneWidget);
    expect(find.text('Salón Aurora'), findsOneWidget);
    expect(find.text('Cargar más'), findsNothing);
  });

  testWidgets('tocar una tarjeta abre el detalle por su id', (tester) async {
    await abrir(
      tester,
      ReservasFalso(
        paginas: [
          PaginaReservas(items: [reservaResumen()], siguiente: null),
        ],
      ),
    );
    await tester.tap(find.text('Corte de cabello'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle /reservas/r1'), findsOneWidget);
  });
}
