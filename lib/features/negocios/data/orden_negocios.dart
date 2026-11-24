import '../mensajes.dart';

/// Orden de la lista de negocios (HU-C21, T17): solo estos dos, porque los
/// negocios no tienen reseñas, calificación, precio ni ubicación con los que
/// ordenar. El cursor de la API solo vale con el orden con el que se obtuvo.
enum OrdenNegocios {
  nombre(MensajesNegocios.ordenNombre, null),
  recientes(MensajesNegocios.ordenRecientes, 'recientes');

  const OrdenNegocios(this.etiqueta, this.valorApi);

  final String etiqueta;

  /// Valor del parámetro `orden`; `null` cuando la API lo toma por omisión.
  final String? valorApi;
}
