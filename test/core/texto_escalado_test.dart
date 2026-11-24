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
import 'package:servia/features/perfil/data/cuenta_con_reservas.dart';
import 'package:servia/features/perfil/data/foto_perfil.dart';
import 'package:servia/features/perfil/data/perfil_cliente.dart';
import 'package:servia/features/perfil/data/selector_foto.dart';
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

// Servicios con categoría de catálogo y personalizada (Móvil#76, T18/T19).
const _corteCategoria = CategoriaServicio(
  id: 'corte-caballero',
  nombre: 'Corte y arreglo de barba para caballero',
);
const _serviciosConCategorias = [
  Servicio(
    id: 's2',
    nombre: 'Corte y arreglo de barba con toalla caliente',
    descripcion: 'Lavado, corte con máquina y tijera, perfilado de barba.',
    precio: 280,
    duracionMin: 75,
    categoriaServicio: _corteCategoria,
  ),
  Servicio(
    id: 's3',
    nombre: 'Perfilado de barba',
    descripcion: 'Perfilado con navaja.',
    precio: 120,
    duracionMin: 30,
    categoriaServicio: CategoriaServicio(id: 'barba', nombre: 'Barba'),
  ),
  Servicio(
    id: 's4',
    nombre: 'Peinado de gala',
    descripcion: 'Peinado para eventos.',
    precio: 300,
    duracionMin: 60,
    categoriaPersonalizada: 'Peinados de gala para bodas y eventos',
  ),
];

class _ServiciosConCategorias extends DetalleServiceFalso {
  @override
  Future<List<Servicio>> obtenerServicios(String negocioId) async =>
      _serviciosConCategorias;

  @override
  Future<Servicio> obtenerServicio(String negocioId, String servicioId) async =>
      _serviciosConCategorias.firstWhere((s) => s.id == servicioId);
}

// PNG de 1x1 para que las imágenes de prueba se decodifiquen sin red.
ImageProvider _imagenDePrueba(String _) => MemoryImage(
  base64.decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC',
  ),
);

final ahora = DateTime.utc(2026, 11, 3, 16, 15);

// Mi perfil de un cliente con foto (HU-C11).
Widget _miPerfilConFoto() => MiPerfilPage(
  authService: SesionPerfilFalsa([]),
  perfilClienteService: PerfilClienteFalso([])
    ..guardado = const PerfilCliente(
      nombre: 'Ana Pérez',
      correo: 'ana@test.com',
      telefono: '4771234567',
      foto: FotoPerfil(id: 'f0', url: 'https://supabase.test/f0.png'),
    ),
  selectorFoto: SelectorFotoFalso(null),
  proveedorFoto: _imagenDePrueba,
);

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
                  nombre: 'Estética Lupita: cortes, color y peinados para toda la familia',
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
        'detalle del servicio con corazón': (
          () => DetalleServicioPage(
            negocioId: 'abc123',
            servicioId: 's2',
            aceptaReservas: true,
            negocioNombre: 'Salón Aurora',
            negociosService: DetalleServiceFalso(),
            favoritos: ApiFavoritosFalsa().controladorServicios(
              SesionFavoritos('ana'),
            ),
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
        'perfil con filtro de categorías de servicio': (
          () => PerfilNegocioPage(
            negocioId: 'abc123',
            negociosService: _ServiciosConCategorias(),
          ),
          null,
        ),
        'detalle del servicio con categoría': (
          () => DetalleServicioPage(
            negocioId: 'abc123',
            servicioId: 's2',
            aceptaReservas: true,
            negocioNombre: 'Salón Aurora',
            negociosService: _ServiciosConCategorias(),
          ),
          null,
        ),
        'detalle del servicio con categoría personalizada': (
          () => DetalleServicioPage(
            negocioId: 'abc123',
            servicioId: 's4',
            aceptaReservas: true,
            negocioNombre: 'Salón Aurora',
            negociosService: _ServiciosConCategorias(),
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
                nombre: 'Estética Lupita: cortes, color y peinados para toda la familia',
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
        'Mis favoritos, pestaña Servicios': (
          () {
            final api = ApiFavoritosFalsa();
            api.serviciosDe('ana').addAll([
              servicioFavorito(
                'n1',
                's1',
                nombre: 'Corte de cabello, peinado y tratamiento hidratante',
                negocioNombre: 'Estética Lupita: cortes, color y peinados para toda la familia',
                precio: 1250.5,
                duracionMin: 135,
              ),
              servicioFavorito('n2', 's2', aceptaReservas: false),
            ]);
            final sesion = SesionFavoritos('ana');
            return FavoritosPage(
              controlador: api.controlador(sesion),
              serviciosControlador: api.controladorServicios(sesion),
              negociosService: NegociosServiceFalso(),
            );
          },
          (t) async {
            await t.tap(find.text('Servicios'));
            await t.pumpAndSettle();
          },
        ),
        'Mis favoritos vacío': (
          () => FavoritosPage(
            controlador: ApiFavoritosFalsa().controlador(
              SesionFavoritos('ana'),
            ),
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
            await t.ensureVisible(
              find.byKey(const Key('boton-enviar-reporte')),
            );
            await t.tap(find.byKey(const Key('boton-enviar-reporte')));
            await t.pumpAndSettle();
          },
        ),
        'Mi perfil con foto': (() => _miPerfilConFoto(), null),
        'Mi perfil con foto y el diálogo de quitarla': (
          () => _miPerfilConFoto(),
          (t) async {
            final quitar = find.text('Quitar foto');
            await t.scrollUntilVisible(quitar, 300);
            await t.tap(quitar);
            await t.pumpAndSettle();
          },
        ),
        'Mi perfil con error al subir la foto': (
          () => MiPerfilPage(
            authService: SesionPerfilFalsa([]),
            perfilClienteService: PerfilClienteFalso(
              [],
              errorAlSubirFoto: const ApiException(
                503,
                'No se pudo guardar la foto en Supabase Storage.',
              ),
            ),
            selectorFoto: SelectorFotoFalso(
              FotoElegida(bytes: png1x1, nombre: 'ana.png'),
            ),
            proveedorFoto: _imagenDePrueba,
          ),
          (t) async {
            final agregar = find.text('Agregar foto');
            await t.scrollUntilVisible(agregar, 300);
            await t.tap(agregar);
            await t.pumpAndSettle();
          },
        ),
        'Mi perfil con el diálogo de eliminar la cuenta': (
          () => _miPerfilConFoto(),
          (t) async {
            final eliminar = find.text('Eliminar mi cuenta');
            await t.scrollUntilVisible(eliminar, 300);
            await t.tap(eliminar);
            await t.pumpAndSettle();
          },
        ),
        'Mi perfil con reservas por atender al eliminar la cuenta': (
          () => MiPerfilPage(
            authService: SesionPerfilFalsa([]),
            perfilClienteService: PerfilClienteFalso([])
              ..errorAlEliminar = CuentaConReservasException(
                mensaje:
                    'No puedes eliminar tu cuenta porque tienes reservas pendientes o confirmadas: SRV-AAAAAA, SRV-BBBBBB. Cancélalas o espera a que terminen.',
                total: 2,
                reservas: [
                  ReservaPorAtender(
                    id: 'r1',
                    folio: 'SRV-AAAAAA',
                    estado: 'pendiente',
                    inicio: DateTime.utc(2026, 11, 25, 16, 30),
                  ),
                  ReservaPorAtender(
                    id: 'r2',
                    folio: 'SRV-BBBBBB',
                    estado: 'confirmada',
                    inicio: DateTime.utc(2026, 12, 2, 1),
                  ),
                ],
              ),
          ),
          (t) async {
            final eliminar = find.text('Eliminar mi cuenta');
            await t.scrollUntilVisible(eliminar, 300);
            await t.tap(eliminar);
            await t.pumpAndSettle();
            await t.enterText(
              find.byKey(const Key('campo-contrasena-eliminar')),
              'clave-correcta',
            );
            await t.tap(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.text('Eliminar cuenta'),
              ),
            );
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
