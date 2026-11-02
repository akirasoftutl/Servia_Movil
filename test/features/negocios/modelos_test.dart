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
