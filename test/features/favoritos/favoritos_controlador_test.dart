import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servia/core/network/api_exception.dart';
import 'package:servia/features/favoritos/data/favoritos_controlador.dart';
import 'package:servia/features/negocios/data/negocio_resumen.dart';

import 'fakes_favoritos.dart';

NegocioResumen resumenDe(String id) =>
    NegocioResumen.fromJson(negocioFavorito(id));

void main() {
  late ApiFavoritosFalsa api;
  late SesionFavoritos sesion;
  late FavoritosControlador controlador;

  setUp(() {
    api = ApiFavoritosFalsa();
    sesion = SesionFavoritos('ana');
    controlador = api.controlador(sesion);
  });

  group('cargar', () {
    test('trae los favoritos del más reciente al más antiguo', () async {
      api.de('ana').addAll([negocioFavorito('b2'), negocioFavorito('b1')]);
      expect(controlador.estado, EstadoFavoritos.inicial);

      final carga = controlador.cargar();
      expect(controlador.estado, EstadoFavoritos.cargando);
      await carga;

      expect(controlador.estado, EstadoFavoritos.listo);
      expect(controlador.items.map((n) => n.id), ['b2', 'b1']);
      expect(controlador.esFavorito('b1'), isTrue);
      expect(controlador.esFavorito('b3'), isFalse);
    });

    test('un error deja el estado en error y se puede reintentar', () async {
      api.errores['GET'] = (codigo: 500, mensaje: 'Falló');
      await controlador.cargar();
      expect(controlador.estado, EstadoFavoritos.error);
      expect(controlador.error, isA<ApiException>());

      api.errores.clear();
      api.de('ana').add(negocioFavorito('b1'));
      await controlador.cargar();
      expect(controlador.estado, EstadoFavoritos.listo);
      expect(controlador.items, hasLength(1));
    });

    test('sin sesión no llama a la API y no hay favoritos', () async {
      sesion.usuario = null;
      await controlador.cargar();
      expect(api.peticiones, isEmpty);
      expect(controlador.haySesion, isFalse);
      expect(controlador.items, isEmpty);
    });

    test(
      'recargar con datos no los esconde mientras llega la respuesta',
      () async {
        api.de('ana').add(negocioFavorito('b1'));
        await controlador.cargar();
        api.retener = Completer<void>();
        final recarga = controlador.cargar();
        expect(controlador.estado, EstadoFavoritos.listo);
        expect(controlador.items, hasLength(1));
        api.retener!.complete();
        await recarga;
      },
    );
  });

  group('alternar', () {
    setUp(() async {
      api.de('ana').add(negocioFavorito('b1'));
      await controlador.cargar();
    });

    test(
      'agregar: el corazón se marca antes de la respuesta y queda primero',
      () async {
        api.retener = Completer<void>();
        final accion = controlador.alternar(resumenDe('b2'));

        expect(controlador.esFavorito('b2'), isTrue);
        expect(controlador.estaGuardando('b2'), isTrue);
        expect(controlador.items.map((n) => n.id), ['b2', 'b1']);

        api.retener!.complete();
        await accion;
        expect(controlador.estaGuardando('b2'), isFalse);
        expect(controlador.esFavorito('b2'), isTrue);
        expect(api.de('ana').map((n) => n['id']), ['b2', 'b1']);
      },
    );

    test('quitar: desaparece al instante y la API lo borra', () async {
      api.retener = Completer<void>();
      final accion = controlador.alternar(resumenDe('b1'));
      expect(controlador.esFavorito('b1'), isFalse);
      expect(controlador.items, isEmpty);
      api.retener!.complete();
      await accion;
      expect(api.de('ana'), isEmpty);
    });

    test('si agregar falla se revierte y el error se propaga', () async {
      api.noDisponibles.add('b2');
      await expectLater(
        controlador.alternar(resumenDe('b2')),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'código', 404)),
      );
      expect(controlador.esFavorito('b2'), isFalse);
      expect(controlador.items.map((n) => n.id), ['b1']);
      expect(controlador.estaGuardando('b2'), isFalse);
    });

    test('si quitar falla vuelve a su lugar', () async {
      api.de('ana').insert(0, negocioFavorito('b0'));
      await controlador.cargar();
      api.errores['DELETE'] = (codigo: 500, mensaje: 'Falló');

      await expectLater(
        controlador.alternar(resumenDe('b1')),
        throwsA(isA<ApiException>()),
      );

      expect(controlador.items.map((n) => n.id), ['b0', 'b1']);
      expect(controlador.esFavorito('b1'), isTrue);
    });

    test('el 409 del tope revierte y trae el mensaje de la API', () async {
      api.tope = 1;
      await expectLater(
        controlador.alternar(resumenDe('b2')),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'código', 409)
              .having(
                (e) => e.mensaje,
                'mensaje',
                contains('Llegaste al máximo'),
              ),
        ),
      );
      expect(controlador.esFavorito('b2'), isFalse);
    });

    test(
      'mientras guarda ignora un segundo toque sobre el mismo negocio',
      () async {
        api.retener = Completer<void>();
        final primera = controlador.alternar(resumenDe('b2'));
        await controlador.alternar(resumenDe('b2'));
        api.retener!.complete();
        await primera;
        expect(api.metodos().where((m) => m.startsWith('PUT')), hasLength(1));
        expect(api.metodos().where((m) => m.startsWith('DELETE')), isEmpty);
      },
    );
  });

  group('cuentas', () {
    test(
      'al entrar con otra cuenta no se ven los favoritos de la anterior',
      () async {
        api.de('ana').add(negocioFavorito('b1'));
        await controlador.cargar();
        expect(controlador.esFavorito('b1'), isTrue);

        sesion.usuario = UsuarioFavoritos('beto');
        api.retener = Completer<void>();
        final carga = controlador.cargar();
        // Antes de que responda la API ya no queda nada de Ana.
        expect(controlador.items, isEmpty);
        expect(controlador.esFavorito('b1'), isFalse);
        expect(controlador.estado, EstadoFavoritos.cargando);
        api.retener!.complete();
        await carga;

        expect(controlador.items, isEmpty);
        expect(controlador.estado, EstadoFavoritos.listo);
      },
    );

    test('limpiar vacía todo (cerrar sesión)', () async {
      api.de('ana').add(negocioFavorito('b1'));
      await controlador.cargar();
      controlador.limpiar();
      expect(controlador.items, isEmpty);
      expect(controlador.estado, EstadoFavoritos.inicial);
      expect(controlador.esFavorito('b1'), isFalse);
    });

    test('una respuesta que llega tras cerrar sesión se descarta', () async {
      api.de('ana').add(negocioFavorito('b1'));
      api.retener = Completer<void>();
      final carga = controlador.cargar();
      controlador.limpiar();
      api.retener!.complete();
      await carga;
      expect(controlador.items, isEmpty);
      expect(controlador.estado, EstadoFavoritos.inicial);
    });
  });
}
