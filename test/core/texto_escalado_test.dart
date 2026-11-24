import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/auth/pages/login_page.dart';
import 'package:servia/features/ayuda/pages/ayuda_page.dart';
import 'package:servia/features/ayuda/pages/reportar_problema_page.dart';
import 'package:servia/features/auth/pages/register_page.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/negocios/data/disponibilidad.dart';
import 'package:servia/features/negocios/data/disponibilidad_service.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/pages/detalle_servicio_page.dart';
import 'package:servia/features/negocios/pages/disponibilidad_page.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';
import 'package:servia/features/perfil/pages/mi_perfil_page.dart';
import 'package:servia/features/reservas/pages/confirmacion_reserva_page.dart';
import 'package:servia/features/reservas/pages/resumen_reserva_page.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/negocios/data/servicio.dart';

import '../features/ayuda/fakes_ayuda.dart';
import '../features/negocios/fakes.dart';
import '../features/perfil/fakes_perfil.dart';
import '../features/reservas/fakes.dart';
import 'tema_de_la_app.dart';

/// Con la fuente real (no la de pruebas) para medir como en el teléfono.
Future<void> cargarFuente() async {
  final cargador = FontLoader('PlusJakartaSans');
  for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/PlusJakartaSans-$peso.ttf')
        .readAsBytesSync();
    cargador.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await cargador.load();
}

class _HorasFalsas extends DisponibilidadService {
  @override
  Future<List<DiaDisponibilidad>> obtenerDias(String n, String s) async => [
    for (var d = 3; d <= 30; d++)
      DiaDisponibilidad(
        fecha: '2026-11-${'$d'.padLeft(2, '0')}',
        disponible: true,
      ),
  ];

  @override
  Future<List<HoraDisponibilidad>> obtenerHoras(
    String n,
    String s,
    String f,
  ) async => const [
    HoraDisponibilidad(hora: '11:30', disponible: true),
    HoraDisponibilidad(hora: '12:30', disponible: false),
  ];
}

const servicio = Servicio(
  id: 's2',
  nombre: 'Corte y arreglo de barba con toalla caliente',
  descripcion: 'Lavado, corte con máquina y tijera, perfilado de barba.',
  precio: 280,
  duracionMin: 75,
);

final ahora = DateTime.utc(2026, 11, 3, 16, 15);

void main() {
  setUpAll(cargarFuente);

  final pantallas =
      <String, (Widget Function(), Future<void> Function(WidgetTester)?)>{
        'inicio de sesión': (
          () => LoginPage(authService: SesionFalsa(conSesion: false)),
          null,
        ),
        'registro': (() => const RegisterPage(), null),
        'inicio con la lista': (
          () {
            final lista = ListaServiceFalso()
              ..responder = (_) async => PaginaNegocios(
                items: [
                  resumen('a'),
                  const NegocioResumen(
                    id: 'b',
                    nombre: 'Estética Lupita: cortes, color y peinados para toda la familia',
                    categoriaId: 'cabello',
                    aceptaReservas: false,
                  ),
                ],
                siguiente: null,
              );
            return HomePage(
              onCerrarSesion: () {},
              negociosService: lista,
              authService: SesionFalsa(conSesion: false),
            );
          },
          null,
        ),
        'perfil del negocio': (
          () => PerfilNegocioPage(
            negocioId: 'abc123',
            negociosService: ServiciosServiceFalso(),
          ),
          null,
        ),
        'detalle del servicio': (
          () => DetalleServicioPage(
            negocioId: 'abc123',
            servicioId: 's2',
            aceptaReservas: true,
            negocioNombre: 'Salón Aurora',
            negociosService: DetalleServiceFalso(),
          ),
          null,
        ),
        'disponibilidad con horas': (
          () => DisponibilidadPage(
            negocioId: 'abc123',
            servicioId: 's2',
            service: _HorasFalsas(),
            ahora: () => ahora,
          ),
          (t) async {
            await t.tap(find.text('4'));
            await t.pumpAndSettle();
          },
        ),
        'resumen de la reserva': (
          () => ResumenReservaPage(
            negocioId: 'abc123',
            negocioNombre: 'Salón Aurora',
            servicio: servicio,
            fecha: '2026-11-04',
            hora: '11:30',
            authService: SesionFalsa(),
            perfilService: PerfilFalso(telefono: '4771234567'),
            reservasService: ReservasFalso(),
            ahora: () => ahora,
          ),
          null,
        ),
        'confirmación de la reserva': (
          () => ConfirmacionReservaPage(
            reserva: reservaCreada(),
            negocioNombre: 'Salón Aurora',
            servicioNombre: servicio.nombre,
            fecha: '2026-11-04',
            hora: '11:30',
          ),
          null,
        ),
        'Mi perfil': (
          () => MiPerfilPage(
            authService: SesionPerfilFalsa([]),
            perfilClienteService: PerfilClienteFalso([]),
          ),
          null,
        ),
        'Ayuda': (
          () => AyudaPage(
            authService: SesionFalsa(),
            soporteService: SoporteFalso(),
          ),
          null,
        ),
        'Ayuda con una pregunta abierta': (
          () => AyudaPage(
            authService: SesionFalsa(),
            soporteService: SoporteFalso(),
          ),
          (t) async {
            await t.scrollUntilVisible(find.text('¿Puedo cancelar?'), 200);
            await t.tap(find.text('¿Puedo cancelar?'));
            await t.pumpAndSettle();
          },
        ),
        'Reportar un problema con reportes': (
          () => ReportarProblemaPage(
            authService: SesionFalsa(),
            soporteService: SoporteFalso(
              existentes: [
                reporte(
                  'No me deja reservar con el negocio de cortes y peinados de mi colonia',
                ),
              ],
            ),
          ),
          null,
        ),
        'Reportar un problema con error al enviar': (
          () => ReportarProblemaPage(
            authService: SesionFalsa(),
            soporteService: SoporteFalso()
              ..fallosAlListar.add(const ApiException(500, 'x'))
              ..fallosAlEnviar.add(
                const ApiException(
                  429,
                  'Enviaste demasiados reportes; inténtalo más tarde.',
                ),
              ),
          ),
          (t) async {
            await t.enterText(
              find.byKey(const Key('campo-asunto')),
              'No me deja reservar con el negocio',
            );
            await t.enterText(
              find.byKey(const Key('campo-descripcion')),
              'Cada vez que intento reservar la pantalla se queda cargando.',
            );
            await t.ensureVisible(find.byKey(const Key('boton-enviar-reporte')));
            await t.tap(find.byKey(const Key('boton-enviar-reporte')));
            await t.pumpAndSettle();
          },
        ),
        'Mi perfil en edición': (
          () => MiPerfilPage(
            authService: SesionPerfilFalsa([]),
            perfilClienteService: PerfilClienteFalso([]),
          ),
          (t) async {
            final botonEditar = find.text('Editar información');
            await t.scrollUntilVisible(botonEditar, 300);
            await t.tap(botonEditar);
            await t.pumpAndSettle();
          },
        ),
      };

  for (final escala in [1.0, 1.5, 2.0]) {
    for (final MapEntry(key: nombre, value: (pantalla, accion))
        in pantallas.entries) {
      testWidgets('$nombre con texto a ${escala}x no se corta ni se desborda', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const SizedBox());
        final tema = temaDeLaApp(tester);
        await tester.pumpWidget(
          MaterialApp(
            theme: tema,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
            home: pantalla(),
          ),
        );
        await tester.pumpAndSettle();
        if (accion != null) await accion(tester);
        expect(tester.takeException(), isNull);
        if (escala == 1.0) {
          // Áreas táctiles de al menos 48 × 48 dp (guía de Android).
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        }
      });
    }
  }
}
