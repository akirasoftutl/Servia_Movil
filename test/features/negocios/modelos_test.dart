import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/negocios/data/categoria.dart';
import 'package:servia/features/negocios/data/negocio.dart';

import 'datos_prueba.dart';

void main() {
  group('perfil público', () {
    test('lee el contrato completo y los días de descanso', () {
      final negocio = Negocio.fromJson(negocioJson());
      expect(negocio.id, 'abc123');
      expect(negocio.nombre, 'Salón Aurora');
      expect(negocio.descripcion, 'Cuidado personal');
      expect(negocio.categoriaId, 'cabello');
      expect(
        negocio.direccionTexto,
        'Calle Luna 12, Col. Centro, 37000, León, Guanajuato',
      );
      expect(negocio.telefono, '4771234567');
      expect(negocio.correoContacto, 'aurora@example.test');
      expect(negocio.aceptaReservas, isTrue);
      expect(negocio.horario.length, 7);
      expect(negocio.horario['lunes']!.abre, '09:00');
      expect(negocio.horario['domingo'], isNull);
    });
    test('negocio viejo: direccion null con direccionTexto se conserva', () {
      final json = negocioJson()..['direccion'] = null;
      json['direccionTexto'] = 'Av. Las Torres 123, Col. Centro';
      expect(
        Negocio.fromJson(json).direccionTexto,
        'Av. Las Torres 123, Col. Centro',
      );
    });
    test('sin direccion ni direccionTexto no hay dirección ni error', () {
      final json = negocioJson()
        ..['direccion'] = null
        ..remove('direccionTexto');
      expect(Negocio.fromJson(json).direccionTexto, isNull);
    });
    test('API anterior: solo direccion en texto se muestra', () {
      final json = negocioJson()
        ..['direccion'] = 'Calle Luna 12, León'
        ..remove('direccionTexto');
      expect(Negocio.fromJson(json).direccionTexto, 'Calle Luna 12, León');
    });
    test('direccionTexto gana sobre direccion en texto', () {
      final json = negocioJson()..['direccion'] = 'Texto viejo';
      expect(
        Negocio.fromJson(json).direccionTexto,
        'Calle Luna 12, Col. Centro, 37000, León, Guanajuato',
      );
    });
    test('direccion objeto sin direccionTexto no rompe ni muestra', () {
      final json = negocioJson()..remove('direccionTexto');
      final negocio = Negocio.fromJson(json);
      expect(negocio.nombre, 'Salón Aurora');
      expect(negocio.direccionTexto, isNull);
    });
    test('direccion como objeto, texto o ausente no rompe la lectura', () {
      for (final direccion in [
        {'calle': 'Luna', 'numeroExterior': '12'},
        <String, dynamic>{},
        'texto suelto',
        42,
      ]) {
        final negocio = Negocio.fromJson(
          negocioJson()..['direccion'] = direccion,
        );
        expect(negocio.nombre, 'Salón Aurora');
        expect(
          negocio.direccionTexto,
          'Calle Luna 12, Col. Centro, 37000, León, Guanajuato',
        );
      }
      final sinCampo = negocioJson()..remove('direccion');
      expect(Negocio.fromJson(sinCampo).nombre, 'Salón Aurora');
    });
    test('carga sin el alias categoria y conserva categoriaId', () {
      final json = negocioJson()..remove('categoria');
      expect(Negocio.fromJson(json).categoriaId, 'cabello');
    });
    test('omite opcionales ausentes o vacíos y teléfono vacío', () {
      for (final vacios in [false, true]) {
        final json = negocioJson()..['telefono'] = '';
        for (final campo in [
          'descripcion',
          'direccionTexto',
          'correoContacto',
        ]) {
          if (vacios) {
            json[campo] = '';
          } else {
            json.remove(campo);
          }
        }
        final negocio = Negocio.fromJson(json);
        expect(negocio.descripcion, isNull);
        expect(negocio.direccionTexto, isNull);
        expect(negocio.correoContacto, isNull);
        expect(negocio.telefono, isNull);
      }
    });
    test('lee portada y galería del perfil público', () {
      final negocio = Negocio.fromJson(
        negocioJson()
          ..['fotos'] = fotosJson(
            portada: fotoJson('p1', 'https://fotos.test/p1.jpg'),
            galeria: [
              fotoJson('g1', 'https://fotos.test/g1.jpg'),
              fotoJson('g2', 'https://fotos.test/g2.jpg'),
            ],
          ),
      );
      expect(negocio.fotos.portada?.id, 'p1');
      expect(negocio.fotos.portada?.url, 'https://fotos.test/p1.jpg');
      expect(
        negocio.fotos.galeria.map((foto) => foto.url).toList(),
        ['https://fotos.test/g1.jpg', 'https://fotos.test/g2.jpg'],
      );
    });
    test('API anterior sin campo fotos se lee como sin fotos', () {
      final negocio = Negocio.fromJson(negocioJson()..remove('fotos'));
      expect(negocio.fotos.portada, isNull);
      expect(negocio.fotos.galeria, isEmpty);
    });
    test('fotos malformadas no rompen la lectura del perfil', () {
      for (final valor in [
        null,
        42,
        'fotos',
        <String, dynamic>{},
        {'portada': 42, 'galeria': 'no es lista'},
        {'portada': {'url': ''}, 'galeria': [1, {'url': 'ok'}]},
      ]) {
        final negocio = Negocio.fromJson(negocioJson()..['fotos'] = valor);
        final galeria = valor is Map ? valor['galeria'] : null;
        expect(negocio.nombre, 'Salón Aurora', reason: '$valor');
        expect(negocio.fotos.portada, isNull, reason: '$valor');
        expect(
          negocio.fotos.galeria.length,
          galeria is List ? 1 : 0,
          reason: '$valor',
        );
      }
    });
    test(
      'rechaza campos ausentes y tipos erróneos con excepción de formato',
      () {
        // La dirección no se valida: un tipo erróneo se ignora sin romper.
        const direccion = ['direccion', 'direccionTexto'];
        for (final campo in negocioJson().keys.where(
          (c) => !direccion.contains(c),
        )) {
          final json = negocioJson()..[campo] = 42;
          expect(
            () => Negocio.fromJson(json),
            throwsFormatException,
            reason: campo,
          );
        }
        for (final campo in [
          'id',
          'nombre',
          'categoriaId',
          'telefono',
          'aceptaReservas',
          'horario',
        ]) {
          expect(
            () => Negocio.fromJson(negocioJson()..remove(campo)),
            throwsFormatException,
          );
        }
        expect(
          () => Negocio.fromJson(negocioJson()..['horario'] = {}),
          throwsFormatException,
        );
      },
    );
    test('rechaza horas inválidas y tipos erróneos en cada extremo', () {
      for (final campo in ['abre', 'cierra']) {
        for (final valor in ['24:00', '09:60', '9:00', '', null, 900]) {
          expect(
            () => HorarioDia.fromJson({
              'abre': '09:00',
              'cierra': '18:00',
              campo: valor,
            }),
            throwsFormatException,
          );
        }
      }
    });
    test('lee y valida el catálogo', () {
      final json = {
        'id': 'cabello',
        'nombre': 'Cabello y barba',
        'orden': 1,
        'activo': true,
      };
      final categoria = Categoria.fromJson(json);
      expect(categoria.nombre, 'Cabello y barba');
      expect(categoria.id, 'cabello');
      expect(categoria.orden, 1);
      expect(categoria.activo, isTrue);
      for (final campo in json.keys) {
        expect(
          () => Categoria.fromJson({...json, campo: null}),
          throwsFormatException,
        );
      }
    });
  });
}
