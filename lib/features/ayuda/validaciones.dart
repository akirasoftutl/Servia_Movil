import 'mensajes.dart';

/// Límites del contrato de `POST /soporte/reportes` (Servia_BE#101). La API
/// vuelve a validar; aquí solo se da el aviso rápido. Se miden sin los
/// espacios de los extremos, igual que en la API.
const asuntoMin = 5;
const asuntoMax = 100;
const descripcionMin = 20;
const descripcionMax = 1000;

bool _enRango(String? valor, int min, int max) {
  final largo = (valor ?? '').trim().length;
  return largo >= min && largo <= max;
}

String? validarAsunto(String? valor) =>
    _enRango(valor, asuntoMin, asuntoMax) ? null : MensajesAyuda.ayudaAsunto;

String? validarDescripcion(String? valor) =>
    _enRango(valor, descripcionMin, descripcionMax)
    ? null
    : MensajesAyuda.ayudaDescripcion;
