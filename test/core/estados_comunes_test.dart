import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/widgets/estados.dart';
import 'package:servia/features/auth/pages/auth_gate.dart';
import 'package:servia/features/negocios/data/disponibilidad.dart';
import 'package:servia/features/negocios/data/disponibilidad_service.dart';
import 'package:servia/features/negocios/data/negocio.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/pages/detalle_servicio_page.dart';
import 'package:servia/features/negocios/pages/disponibilidad_page.dart';
import 'package:servia/features/negocios/pages/lista_negocios_page.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';
import 'package:servia/features/negocios/rutas_negocios.dart';
import 'package:servia/features/perfil/pages/mi_perfil_page.dart';

import '../features/negocios/fakes.dart';
import '../features/perfil/fakes_perfil.dart';
import '../features/reservas/fakes.dart';

class _DiasFalsos extends DisponibilidadService {
  _DiasFalsos({this.error});
  final Object? error;

  @override
  Future<List<DiaDisponibilidad>> obtenerDias(String n, String s) async {
    if (error != null) throw error!;
    return const [];
  }

  @override
  Future<List<HoraDisponibilidad>> obtenerHoras(
    String n,
    String s,
    String f,
  ) async => [];
}

/// Monta la pantalla desde cero (sin reutilizar el estado de la anterior).
Future<void> abrir(WidgetTester tester, Widget pantalla) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pumpAndSettle();
}

void main() {
  group('los estados comunes', () {
    testWidgets('cargando muestra un solo indicador', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EstadoCargando())),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('vacío muestra el ícono y el mensaje, sin reintentar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EstadoVacio(
              icono: Icons.storefront_outlined,
              mensaje: 'Nada',
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);
      expect(find.text('Nada'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('error ofrece «Reintentar» solo si hay cómo reintentar', (
      tester,
    ) async {
      var reintentos = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EstadoError(
              mensaje: 'Falló',
              onReintentar: () => reintentos++,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(find.text('Falló'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(reintentos, 1);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EstadoError(mensaje: 'Falló')),
        ),
      );
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('con texto grande se desplaza en vez de desbordarse', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: EstadoError(
                mensaje:
                    'No se pudo conectar. Revisa tu conexión e '
                        'inténtalo de nuevo. ' *
                    3,
                onReintentar: () {},
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('cada pantalla usa los estados comunes', () {
    testWidgets('lista: cargando, vacía, sin resultados y error', (
      tester,
    ) async {
      final pendiente = Completer<PaginaNegocios>();
      final cargando = ListaServiceFalso()..responder = (_) => pendiente.future;
      await tester.pumpWidget(
        MaterialApp(home: ListaNegociosPage(negociosService: cargando)),
      );
      await tester.pump();
      expect(find.byType(EstadoCargando), findsOneWidget);

      await abrir(
        tester,
        ListaNegociosPage(negociosService: ListaServiceFalso()),
      );
      expect(find.byType(EstadoVacio), findsOneWidget);

      final error = ListaServiceFalso()
        ..responder = (_) async => throw Exception('red');
      await abrir(tester, ListaNegociosPage(negociosService: error));
      expect(find.byType(EstadoError), findsOneWidget);
    });

    testWidgets('perfil del negocio: cargando y error', (tester) async {
      final cargando = NegociosServiceFalso()..pendiente = Completer<Negocio>();
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilNegocioPage(
            negocioId: 'abc123',
            negociosService: cargando,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(EstadoCargando), findsOneWidget);

      await abrir(
        tester,
        PerfilNegocioPage(
          negocioId: 'abc123',
          negociosService: NegociosServiceFalso(error: Exception('red')),
        ),
      );
      expect(find.byType(EstadoError), findsOneWidget);
    });

    testWidgets('servicios del negocio: vacío y error', (tester) async {
      await abrir(
        tester,
        PerfilNegocioPage(
          negocioId: 'abc123',
          negociosService: ServiciosServiceFalso()..servicios = [],
        ),
      );
      expect(find.byType(EstadoVacio), findsOneWidget);

      await abrir(
        tester,
        PerfilNegocioPage(
          negocioId: 'abc123',
          negociosService: ServiciosServiceFalso()
            ..errorServicios = Exception('red'),
        ),
      );
      expect(find.byType(EstadoError), findsOneWidget);
    });

    testWidgets('detalle del servicio: error', (tester) async {
      await abrir(
        tester,
        DetalleServicioPage(
          negocioId: 'abc123',
          servicioId: 's2',
          aceptaReservas: true,
          negocioNombre: 'Salón Aurora',
          negociosService: DetalleServiceFalso()..errorDetalle = Exception(),
        ),
      );
      expect(find.byType(EstadoError), findsOneWidget);
    });

    testWidgets('disponibilidad: error y sin días', (tester) async {
      await abrir(
        tester,
        DisponibilidadPage(
          negocioId: 'abc123',
          servicioId: 's2',
          service: _DiasFalsos(error: Exception('red')),
        ),
      );
      expect(find.byType(EstadoError), findsOneWidget);

      await abrir(
        tester,
        DisponibilidadPage(
          negocioId: 'abc123',
          servicioId: 's2',
          service: _DiasFalsos(),
        ),
      );
      expect(find.byType(EstadoVacio), findsOneWidget);
    });

    testWidgets('Mi perfil: error', (tester) async {
      await abrir(
        tester,
        MiPerfilPage(
          authService: SesionPerfilFalsa([]),
          perfilClienteService: PerfilClienteFalso([], error: Exception()),
        ),
      );
      expect(find.byType(EstadoError), findsOneWidget);
    });

    testWidgets('inicio (AuthGate): error de red', (tester) async {
      await abrir(
        tester,
        AuthGate(
          authService: SesionFalsa(),
          perfilService: PerfilFalso(error: Exception('red')),
        ),
      );
      expect(find.byType(EstadoError), findsOneWidget);
    });

    testWidgets('ruta inexistente: vacío', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.pushNamed(context, '/no-existe'),
              child: const Text('ir'),
            ),
          ),
          onGenerateRoute: generarRutaNegocios,
          onUnknownRoute: generarRutaNoDisponible,
        ),
      );
      await tester.tap(find.text('ir'));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoVacio), findsOneWidget);
    });
  });
}
