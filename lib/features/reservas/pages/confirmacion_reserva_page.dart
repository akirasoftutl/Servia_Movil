import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../negocios/formatos.dart';
import '../data/reserva_creada.dart';
import '../fechas_reserva.dart';
import '../mensajes.dart';

/// Confirmación de la solicitud enviada: folio, estado Pendiente y plazo (MVP-18).
class ConfirmacionReservaPage extends StatelessWidget {
  const ConfirmacionReservaPage({
    super.key,
    required this.reserva,
    required this.negocioNombre,
    required this.servicioNombre,
    required this.fecha,
    required this.hora,
  });

  final ReservaCreada reserva;
  final String negocioNombre;
  final String servicioNombre;
  final String fecha;
  final String hora;

  void _volver(BuildContext context) =>
      Navigator.of(context).popUntil((ruta) => ruta.isFirst);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (salio, _) {
        if (!salio) _volver(context);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Cabecera limpia centrada
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Text(
                  MensajesReservas.confirmacionTitulo,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF3F4F6)),

              // Contenido principal desplazable
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, Espacios.xxl),
                  children: [
                    // Tarjeta principal con ícono de éxito, folio seleccionable y estado
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 34,
                              color: Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            MensajesReservas.folio,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(
                              reserva.folio,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                                letterSpacing: 1.2,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                '${MensajesReservas.estado}: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  MensajesReservas.estadoPendiente,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bloque de aviso sobre el tiempo de respuesta (estilo píldora informativa)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 20,
                            color: Color(0xFF7C3AED),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              MensajesReservas.avisoDosHoras,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF374151),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tarjeta de resumen del servicio reservado
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            servicioNombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            negocioNombre,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(
                              height: 1,
                              color: Color(0xFFF3F4F6),
                            ),
                          ),
                          _FilaDetalleConfirmacion(
                            icono: Icons.calendar_today_rounded,
                            texto: '${formatearFechaLarga(fecha)}, $hora',
                          ),
                          const SizedBox(height: 10),
                          _FilaDetalleConfirmacion(
                            icono: Icons.payments_outlined,
                            texto:
                                '${formatearDuracion(reserva.duracionMin)} · ${formatearPrecio(reserva.precio)}',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Botón principal fijo abajo tipo píldora negra
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => _volver(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F0F0F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text(MensajesReservas.volverAlInicio),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaDetalleConfirmacion extends StatelessWidget {
  const _FilaDetalleConfirmacion({
    required this.icono,
    required this.texto,
  });

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 17, color: const Color(0xFF6B7280)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}