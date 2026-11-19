import 'package:flutter_test/flutter_test.dart';
import 'package:servia/features/reservas/fechas_reserva.dart';

void main() {
  test('el inicio se lee en America/Mexico_City y va con zona -06:00', () {
    expect(
      inicioIsoConZona('2026-11-10', '10:00'),
      '2026-11-10T10:00:00-06:00',
    );
    expect(
      inicioIsoConZona('2026-07-04', '09:30'),
      '2026-07-04T09:30:00-06:00',
    );
    // 10:00 de México son las 16:00 UTC, sin importar la zona del teléfono.
    expect(
      inicioDeCita('2026-11-10', '10:00').toUtc(),
      DateTime.utc(2026, 11, 10, 16),
    );
  });

  group('aviso de cancelación (D4): cita en menos de 24 horas', () {
    final inicio = inicioDeCita('2026-11-10', '10:00'); // 16:00 UTC

    test('un minuto antes del límite avisa', () {
      expect(
        citaEnMenosDe24Horas(inicio, DateTime.utc(2026, 11, 9, 16, 1)),
        isTrue,
      );
    });

    test('justo a 24 horas todavía se puede cancelar: no avisa', () {
      expect(
        citaEnMenosDe24Horas(inicio, DateTime.utc(2026, 11, 9, 16)),
        isFalse,
      );
    });

    test('con más de 24 horas no avisa', () {
      expect(
        citaEnMenosDe24Horas(inicio, DateTime.utc(2026, 11, 8, 12)),
        isFalse,
      );
    });

    test('se cuenta con la hora de México aunque ahora venga en otra zona', () {
      // Faltan 23 h 30 min para las 10:00 de México (16:00 UTC): avisa.
      expect(
        citaEnMenosDe24Horas(inicio, DateTime.utc(2026, 11, 9, 16, 30)),
        isTrue,
      );
      // Con 10:00 leído como UTC (error típico) faltarían 23 h 30 min: avisaría.
      expect(
        citaEnMenosDe24Horas(
          inicioDeCita('2026-11-10', '10:00'),
          DateTime.utc(2026, 11, 9, 10, 30),
        ),
        isFalse,
      );
    });
  });

  test('fecha larga en español', () {
    expect(formatearFechaLarga('2026-11-10'), 'martes 10 de noviembre de 2026');
    expect(formatearFechaLarga('2026-12-06'), 'domingo 6 de diciembre de 2026');
  });

  test(
    'un ISO UTC se lee en America/Mexico_City, nunca en la zona del teléfono',
    () {
      final inicio = DateTime.utc(2026, 11, 10, 16); // 10:00 de México
      expect(fechaEnMexico(inicio), '2026-11-10');
      expect(horaEnMexico(inicio), '10:00');

      // Medianoche en México ya es día siguiente en UTC.
      final noche = DateTime.utc(2026, 11, 11, 6); // 00:00 del 11 en México
      expect(fechaEnMexico(noche), '2026-11-11');
      expect(horaEnMexico(noche), '00:00');
    },
  );
}
