import 'lectura_json.dart';
import 'negocio_resumen.dart';

class NegocioCercano {
  const NegocioCercano({required this.negocio, required this.distanciaKm});
  final NegocioResumen negocio;
  final double distanciaKm;

  factory NegocioCercano.fromJson(Map<String, dynamic> json) {
    final distancia = json['distanciaKm'];
    if (distancia is! num || !distancia.isFinite || distancia < 0) {
      throw const FormatException('Distancia inválida.');
    }
    return NegocioCercano(
      negocio: NegocioResumen.fromJson(leerObjeto(json)),
      distanciaKm: distancia.toDouble(),
    );
  }
}
