import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../auth/data/auth_service.dart';
import '../data/soporte_service.dart';
import '../mensajes.dart';
import '../preguntas_frecuentes.dart';
import 'reportar_problema_page.dart';

/// Ayuda del cliente: preguntas frecuentes (texto fijo) y la entrada a
/// «Reportar un problema» (HU-C114 a HU-C117, T17).
class AyudaPage extends StatelessWidget {
  const AyudaPage({super.key, this.authService, this.soporteService});

  final AuthService? authService;
  final SoporteService? soporteService;

  void _reportar(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportarProblemaPage(
          authService: authService,
          soporteService: soporteService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puedeRegresar = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado minimalista estilo Fresha
            Padding(
              padding: EdgeInsets.fromLTRB(
                puedeRegresar ? 12 : 20,
                16,
                20,
                14,
              ),
              child: Row(
                children: [
                  if (puedeRegresar) ...[
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF111827),
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Expanded(
                    child: Text(
                      MensajesAyuda.tituloAyuda,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, Espacios.xxl),
                children: [
                  Semantics(
                    header: true,
                    child: const Text(
                      MensajesAyuda.preguntasFrecuentes,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final seccion in seccionesAyuda) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 10),
                      child: Semantics(
                        header: true,
                        child: Text(
                          seccion.titulo,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    for (final pregunta in seccion.preguntas)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _Pregunta(
                          pregunta: pregunta,
                          alReportar: () => _reportar(context),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _reportar(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F0F0F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text(MensajesAyuda.botonReportar),
                    ),
                  ),
                  const SizedBox(height: Espacios.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pregunta extends StatelessWidget {
  const _Pregunta({required this.pregunta, required this.alReportar});

  final PreguntaFrecuente pregunta;
  final VoidCallback alReportar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: const Color(0xFFF9FAFB),
          highlightColor: const Color(0xFFF9FAFB),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: const Color(0xFF111827),
          collapsedIconColor: const Color(0xFF6B7280),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            pregunta.pregunta,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
              height: 1.35,
            ),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),
            Text(
              pregunta.respuesta,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF4B5563),
                height: 1.45,
              ),
            ),
            if (pregunta.ofreceReportar) ...[
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: alReportar,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text(MensajesAyuda.botonReportar),
              ),
            ],
          ],
        ),
      ),
    );
  }
}