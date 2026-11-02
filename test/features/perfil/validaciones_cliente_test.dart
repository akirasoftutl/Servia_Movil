import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/auth/validaciones.dart';

void main() {
  group('ValidacionesCliente (mismas reglas que el registro, MVP-01)', () {
    test('teléfono: exactamente 10 dígitos', () {
      expect(ValidacionesCliente.telefono('4771234567'), isNull);
      expect(
        ValidacionesCliente.telefono('477123456'),
        'El teléfono debe contener exactamente 10 dígitos numéricos.',
      );
      expect(
        ValidacionesCliente.telefono('47712345a7'),
        'El teléfono debe contener exactamente 10 dígitos numéricos.',
      );
      expect(ValidacionesCliente.telefono(' '), 'El teléfono es obligatorio.');
    });

    test('correo: obligatorio y con formato válido', () {
      expect(ValidacionesCliente.correo(' ana@test.com '), isNull);
      expect(
        ValidacionesCliente.correo('ana@test'),
        'El correo debe tener un formato válido.',
      );
      expect(ValidacionesCliente.correo(''), 'El correo es obligatorio.');
    });

    test('nombre: de 2 a 100 caracteres', () {
      expect(ValidacionesCliente.nombre('Ana'), isNull);
      expect(
        ValidacionesCliente.nombre('A'),
        'El nombre debe tener al menos 2 caracteres.',
      );
      expect(
        ValidacionesCliente.nombre('A' * 101),
        'El nombre no puede exceder 100 caracteres.',
      );
      expect(ValidacionesCliente.nombre(null), 'El nombre es obligatorio.');
    });
  });
}
