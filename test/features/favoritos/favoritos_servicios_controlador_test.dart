import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/favoritos/data/favoritos_controlador.dart';
import 'package:servia/features/favoritos/data/favoritos_servicios_controlador.dart';
import 'package:servia/features/favoritos/data/servicio_favorito.dart';

import 'fakes_favoritos.dart';

ServicioFavorito servicioDe(String negocioId, String servicioId) =>
    ServicioFavorito.fromJson(servicioFavorito(negocioId, servicioId));

void main() {
  late ApiFavoritosFalsa api;
  late SesionFavoritos sesion;
  late FavoritosServiciosControlador controlador;

  setUp(() {
    api = ApiFavoritosFalsa();
    sesion = SesionFavoritos('ana');
    controlador = api.controladorServicios(sesion);
  });

  group('cargar', () {
    test('trae los favoritos del más reciente al más antiguo', () async {
      api.serviciosDe('ana').addAll([
        servicioFavorito('n1', 's2'),
        servicioFavorito('n2', 's1'),
      ]);
      expect(controlador.estado, EstadoFavoritos.inicial);

      final carga = controlador.cargar();
      expect(controlador.estado, EstadoFavoritos.cargando);
      await carga;

      expect(controlador.estado, EstadoFavoritos.listo);
      expect(controlador.items.map((s) => s.clave), ['n1/s2', 'n2/s1']);
      expect(controlador.esFavorito('n2', 's1'), isTrue);
      expect(controlador.esFavorito('n1', 's1'), isFalse);
    });

    test('el mismo servicioId de otro negocio no es el mismo favorito', () async {
      api.serviciosDe('ana').add(servicioFavorito('n1', 's1'));
      await controlador.cargar();
      expect(controlador.esFavorito('n1', 's1'), isTrue);
      expect(controlador.esFavorito('n2', 's1'), isFalse);
    });

    test('no mezcla los favoritos de negocios con los de servicios', () async {
      api.de('ana').add(negocioFavorito('n1'));
      api.serviciosDe('ana').add(servicioFavorito('n1', 's1'));
      final negocios = api.controlador(sesion);

      await controlador.cargar();
      await negocios.cargar();

      expect(controlador.items.map((s) => s.clave), ['n1/s1']);
      expect(negocios.items.map((n) => n.id), ['n1']);
      expect(api.metodos(), [
        'GET /favoritos/servicios',
        'GET /favoritos/negocios',
      ]);
    });

    test('un error deja el estado en error y se puede reintentar', () async {
      api.erroresServicios['GET'] = (codigo: 500, mensaje: 'Falló');
      await controlador.cargar();
      expect(controlador.estado, EstadoFavoritos.error);
      expect(controlador.error, isA<ApiException>());

      api.erroresServicios.clear();
      api.serviciosDe('ana').add(servicioFavorito('n1', 's1'));
      await controlador.cargar();
      expect(controlador.estado, EstadoFavoritos.listo);
      expect(controlador.items, hasLength(1));
    });

    test('sin sesión no consulta la API y queda vacío', () async {
      sesion.usuario = null;
      await controlador.cargar();
      expect(controlador.estado, EstadoFavoritos.inicial);
      expect(controlador.items, isEmpty);
      expect(api.peticiones, isEmpty);
    });
  });

  group('alternar', () {
    test('agregar: aparece al instante arriba y se guarda con PUT', () async {
      api.serviciosDe('ana').add(servicioFavorito('n1', 's1'));
      await controlador.cargar();
      api.retener = Completer<void>();

      final futuro = controlador.alternar(servicioDe('n2', 's7'));
      expect(controlador.items.map((s) => s.clave), ['n2/s7', 'n1/s1']);
      expect(controlador.estaGuardando('n2', 's7'), isTrue);

      api.retener!.complete();
      await futuro;

      expect(controlador.estaGuardando('n2', 's7'), isFalse);
      expect(api.metodos().last, 'PUT /favoritos/servicios/n2/s7');
      expect(api.serviciosDe('ana').first['servicioId'], 's7');
    });

    test('quitar: desaparece al instante y se borra con DELETE', () async {
      api.serviciosDe('ana')
        ..add(servicioFavorito('n1', 's2'))
        ..add(servicioFavorito('n1', 's1'));
      await controlador.cargar();
      api.retener = Completer<void>();

      final futuro = controlador.alternar(servicioDe('n1', 's1'));
      expect(controlador.esFavorito('n1', 's1'), isFalse);
      api.retener!.complete();
      await futuro;

      expect(api.metodos().last, 'DELETE /favoritos/servicios/n1/s1');
      expect(api.serviciosDe('ana').map((s) => s['servicioId']), ['s2']);
    });

    test('404 al agregar: revierte y lanza el error', () async {
      await controlador.cargar();
      api.serviciosNoDisponibles.add('n1/s1');

      await expectLater(
        controlador.alternar(servicioDe('n1', 's1')),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'c', 404)),
      );

      expect(controlador.esFavorito('n1', 's1'), isFalse);
      expect(controlador.estaGuardando('n1', 's1'), isFalse);
    });

    test('409 al agregar: revierte y lanza el error', () async {
      await controlador.cargar();
      api.topeServicios = 0;
      await expectLater(
        controlador.alternar(servicioDe('n1', 's1')),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'c', 409)),
      );
      expect(controlador.items, isEmpty);
    });

    test('si quitar falla, el servicio vuelve a su lugar', () async {
      api.serviciosDe('ana')
        ..add(servicioFavorito('n1', 's3'))
        ..add(servicioFavorito('n1', 's2'))
        ..add(servicioFavorito('n1', 's1'));
      await controlador.cargar();
      api.erroresServicios['DELETE'] = (codigo: 500, mensaje: 'Falló');

      await expectLater(
        controlador.alternar(servicioDe('n1', 's2')),
        throwsA(isA<ApiException>()),
      );

      expect(controlador.items.map((s) => s.servicioId), ['s3', 's2', 's1']);
    });

    test('sin sesión lanza 401 y no llama a la API', () async {
      sesion.usuario = null;
      await expectLater(
        controlador.alternar(servicioDe('n1', 's1')),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'c', 401)),
      );
      expect(api.peticiones, isEmpty);
    });

    test('mientras guarda, otro toque sobre el mismo servicio se ignora', () async {
      await controlador.cargar();
      api.retener = Completer<void>();
      final primero = controlador.alternar(servicioDe('n1', 's1'));
      await controlador.alternar(servicioDe('n1', 's1'));
      api.retener!.complete();
      await primero;
      expect(api.metodos().where((m) => m.startsWith('PUT')), hasLength(1));
    });
  });

  group('cuenta (RN-46)', () {
    test('limpiar descarta la lista y las respuestas atrasadas', () async {
      api.serviciosDe('ana').add(servicioFavorito('n1', 's1'));
      api.retener = Completer<void>();
      final carga = controlador.cargar();
      controlador.limpiar();
      api.retener!.complete();
      await carga;

      expect(controlador.estado, EstadoFavoritos.inicial);
      expect(controlador.items, isEmpty);
    });

    test('al entrar con otra cuenta no se ven los servicios de la anterior', () async {
      api.serviciosDe('ana').add(servicioFavorito('n1', 's1'));
      await controlador.cargar();
      expect(controlador.items, hasLength(1));

      sesion.usuario = UsuarioFavoritos('beto');
      await controlador.cargar();

      expect(controlador.items, isEmpty);
      expect(controlador.esFavorito('n1', 's1'), isFalse);
      expect(api.peticiones.last.headers['Authorization'], 'Bearer token-beto');
    });

    test('la instancia de la app existe y empieza vacía', () {
      expect(FavoritosServiciosControlador.instancia.items, isEmpty);
    });
  });
}
