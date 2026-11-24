import 'dart:async';

import 'package:servia/features/ayuda/data/reporte.dart';
import 'package:servia/features/ayuda/data/soporte_service.dart';

/// Reporte con la forma real de la API (Servia_BE#101: id, asunto, estado,
/// creadaEn ISO 8601 en UTC).
Reporte reporte(String asunto, {String id = 'r1', DateTime? creadaEn}) =>
    Reporte(
      id: id,
      asunto: asunto,
      estado: 'abierto',
      creadaEn: creadaEn ?? DateTime.utc(2026, 11, 24, 20, 5),
    );

/// Hace de la API de soporte: guarda en memoria y anota cada llamada.
class SoporteFalso extends SoporteService {
  SoporteFalso({List<Reporte> existentes = const []})
    : reportes = [...existentes];

  final List<Reporte> reportes;

  /// Lo que lanza cada envío (null = éxito). Se consume en orden.
  final List<Object?> fallosAlEnviar = [];
  final List<Object?> fallosAlListar = [];

  /// Si no es null, el envío espera a que se complete.
  Completer<void>? esperaEnvio;

  final enviados = <({String token, String asunto, String descripcion})>[];
  int listados = 0;
  final tokens = <String>[];

  @override
  Future<Reporte?> enviar(
    String token, {
    required String asunto,
    required String descripcion,
  }) async {
    tokens.add(token);
    enviados.add((token: token, asunto: asunto, descripcion: descripcion));
    await esperaEnvio?.future;
    if (fallosAlEnviar.isNotEmpty) {
      final fallo = fallosAlEnviar.removeAt(0);
      if (fallo != null) throw fallo;
    }
    final nuevo = reporte(asunto, id: 'n${enviados.length}');
    reportes.insert(0, nuevo);
    return nuevo;
  }

  @override
  Future<List<Reporte>> listarMios(String token) async {
    tokens.add(token);
    listados++;
    if (fallosAlListar.isNotEmpty) {
      final fallo = fallosAlListar.removeAt(0);
      if (fallo != null) throw fallo;
    }
    return [...reportes];
  }
}
