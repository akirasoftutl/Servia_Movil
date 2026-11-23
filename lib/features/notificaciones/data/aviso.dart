import '../../negocios/data/lectura_json.dart';
import '../../reservas/fechas_reserva.dart';

/// Un aviso de reserva del cliente (`GET /notificaciones`).
///
/// `creadaEn` llega como ISO 8601 (normalmente UTC); se muestra siempre en
/// America/Mexico_City, igual que el resto de fechas de la app.
class Aviso {
  const Aviso({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.cuerpo,
    required this.leida,
    required this.creadaEn,
    this.reservaId,
  });

  final String id;
  final String tipo;
  final String titulo;
  final String cuerpo;
  final bool leida;
  final DateTime creadaEn;
  final String? reservaId;

  factory Aviso.fromJson(Map<String, dynamic> json) {
    final creada = DateTime.tryParse(leerTexto(json, 'creadaEn'));
    if (creada == null) {
      throw const FormatException('Campo inválido: creadaEn.');
    }
    return Aviso(
      id: leerTexto(json, 'id'),
      tipo: leerTexto(json, 'tipo'),
      titulo: leerTexto(json, 'titulo'),
      cuerpo: leerTexto(json, 'cuerpo'),
      leida: leerBooleano(json, 'leida'),
      creadaEn: creada,
      reservaId: leerTextoOpcional(json, 'reservaId'),
    );
  }

  Aviso conLeida(bool valor) => Aviso(
        id: id,
        tipo: tipo,
        titulo: titulo,
        cuerpo: cuerpo,
        leida: valor,
        creadaEn: creadaEn,
        reservaId: reservaId,
      );
}

/// Respuesta paginada de `GET /notificaciones`, con el total de no leídos.
class PaginaAvisos {
  const PaginaAvisos({
    required this.items,
    required this.noLeidas,
    required this.siguiente,
  });

  final List<Aviso> items;
  final int noLeidas;
  final String? siguiente;

  factory PaginaAvisos.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final siguiente = json['siguiente'];
    if (items is! List ||
        !json.containsKey('noLeidas') ||
        !json.containsKey('siguiente') ||
        (siguiente != null && siguiente is! String)) {
      throw const FormatException('Página de avisos inválida.');
    }
    return PaginaAvisos(
      items: List.unmodifiable(
        items.map((item) => Aviso.fromJson(leerObjeto(item))),
      ),
      noLeidas: leerEntero(json, 'noLeidas'),
      siguiente: siguiente as String?,
    );
  }
}

/// `2026-11-22T10:05:00Z` -> `domingo 22 de noviembre de 2026 · 04:05`.
String formatearFechaAviso(DateTime creadaEn) {
  final fecha = fechaEnMexico(creadaEn);
  return '${formatearFechaLarga(fecha)} · ${horaEnMexico(creadaEn)}';
}
