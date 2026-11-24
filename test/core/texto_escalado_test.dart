import 'dart:convert' show base64;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/auth/pages/login_page.dart';
import 'package:servia/features/ayuda/pages/ayuda_page.dart';
import 'package:servia/features/ayuda/pages/reportar_problema_page.dart';
import 'package:servia/features/auth/pages/register_page.dart';
import 'package:servia/features/favoritos/pages/favoritos_page.dart';
import 'package:servia/features/home/pages/home_page.dart';
import 'package:servia/features/negocios/data/disponibilidad.dart';
import 'package:servia/features/negocios/data/disponibilidad_service.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';
import 'package:servia/features/negocios/pages/detalle_servicio_page.dart';
import 'package:servia/features/negocios/pages/disponibilidad_page.dart';
import 'package:servia/features/negocios/pages/perfil_negocio_page.dart';
import 'package:servia/features/perfil/pages/mi_perfil_page.dart';
import 'package:servia/features/reservas/data/detalle_reserva.dart';
import 'package:servia/features/reservas/pages/confirmacion_reserva_page.dart';
import 'package:servia/features/reservas/pages/reprogramar_reserva_page.dart';
import 'package:servia/features/reservas/pages/resumen_reserva_page.dart';
import 'package:servia/features/negocios/data/fotos_negocio.dart';
import 'package:servia/features/negocios/data/servicio.dart';

import '../features/negocios/datos_prueba.dart' show serviciosPrueba;
import 'package:servia/core/network/api_exception.dart';

import '../features/favoritos/fakes_favoritos.dart';
import '../features/ayuda/fakes_ayuda.dart';
import '../features/negocios/fakes.dart';
import '../features/negocios/fakes_destacados.dart';
import '../features/perfil/fakes_perfil.dart';
import '../features/reservas/escenario_reprogramar.dart';
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

// Servicio con las 3 imágenes que permite T19 (HU-C32).
const servicioConImagenes = Servicio(
  id: 's2',
  nombre: 'Corte y arreglo de barba con toalla caliente',
  descripcion: 'Lavado, corte con máquina y tijera, perfilado de barba.',
  precio: 280,
  duracionMin: 75,
  imagenes: [
    FotoNegocio(id: 'i1', url: 'https://supabase.test/s2/i1.jpg'),
    FotoNegocio(id: 'i2', url: 'https://supabase.test/s2/i2.jpg'),
    FotoNegocio(id: 'i3', url: 'https://supabase.test/s2/i3.jpg'),
  ],
);

class _ServiciosConImagenes extends DetalleServiceFalso {
  @override
  Future<List<Servicio>> obtenerServicios(String negocioId) async => [
    servicioConImagenes,
    ...serviciosPrueba,
  ];

  @override
  Future<Servicio> obtenerServicio(String negocioId, String servicioId) async =>
      servicioConImagenes;
}

// PNG de 1x1 para que las imágenes de prueba se decodifiquen sin red.
ImageProvider _imagenDePrueba(String _) => MemoryImage(
  base64.decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
  ),
);

final ahora = DateTime.utc(2026, 11, 3, 16, 15);

Widget _reprogramar(EscenarioReprogramar e) => ReprogramarReservaPage(
  reserva: DetalleReserva.fromJson(detalleApi()),
  authService: e.sesion,
  reservasService: e.reservas,
  negociosService: e.negocios,
  disponibilidadService: e.disponibilidad,
  ahora: () => ahora,
);

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
        'inicio con destacados': (
          () {
            final lista = ListaConDestacados()
              ..destacados = [
                destacado('d1'),
                const NegocioResumen(
                  id: 'd2',
                  nombre:
                      'Estética Lupita: cortes, color y peinados para toda la familia',
                  categoriaId: 'cabello',
                  aceptaReservas: false,
                ),
              ]
              ..responder = (_) async =>
                  PaginaNegocios(items: [resumen('a')], siguiente: null);
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
        'perfil del negocio con corazón': (
          () => PerfilNegocioPage(
            negocioId: 'abc123',
            negociosService: ServiciosServiceFalso(),
            favoritos: ApiFavoritosFalsa().controlador(SesionFavoritos('ana')),
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
        'perfil con servicios con imágenes': (
          () => PerfilNegocioPage(
            negocioId: 'abc123',
            negociosService: _ServiciosConImagenes(),
            proveedorFotos: _imagenDePrueba,
          ),
          null,
        ),
        'detalle del servicio con imágenes': (
          () => DetalleServicioPage(
            negocioId: 'abc123',
            servicioId: 's2',
            aceptaReservas: true,
            negocioNombre: 'Salón Aurora',
            negociosService: _ServiciosConImagenes(),
            proveedorImagenes: _imagenDePrueba,
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
        'detalle de reserva con «Cambiar fecha u hora»': (
          () => EscenarioReprogramar().detallePage(),
          null,
        ),
        'cambiar fecha u hora de una reserva': (
          () => _reprogramar(EscenarioReprogramar()),
          null,
        ),
        'cambiar de servicio de una reserva': (
          () => _reprogramar(EscenarioReprogramar()),
          (t) async {
            await t.tap(find.text('Cambiar de servicio'));
            await t.pumpAndSettle();
          },
        ),
        'confirmar el cambio de una reserva': (
          () => _reprogramar(EscenarioReprogramar()),
          (t) async {
            await t.ensureVisible(find.text('Elegir nueva fecha y hora'));
            await t.tap(find.text('Elegir nueva fecha y hora'));
            await t.pumpAndSettle();
            await t.tap(find.text('4'));
            await t.pumpAndSettle();
            await t.ensureVisible(find.byKey(const ValueKey('hora-09:30')));
            await t.tap(find.byKey(const ValueKey('hora-09:30')));
            await t.pumpAndSettle();
          },
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
        'Mis favoritos': (
          () {
            final api = ApiFavoritosFalsa();
            api.de('ana').addAll([
              negocioFavorito(
                'b1',
                nombre:
                    'Estética Lupita: cortes, color y peinados para toda la familia',
                aceptaReservas: false,
              ),
              negocioFavorito('b2', nombre: 'Salón Aurora'),
            ]);
            return FavoritosPage(
              controlador: api.controlador(SesionFavoritos('ana')),
              negociosService: NegociosServiceFalso(),
            );
          },
          null,
        ),
        'Mis favoritos vacío': (
          () => FavoritosPage(
            controlador: ApiFavoritosFalsa().controlador(SesionFavoritos('ana')),
            negociosService: NegociosServiceFalso(),
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
