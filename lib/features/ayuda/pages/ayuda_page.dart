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
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(MensajesAyuda.tituloAyuda)),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: Espacios.pantalla,
          children: [
            Semantics(
              header: true,
              child: Text(
                MensajesAyuda.preguntasFrecuentes,
                style: tema.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: Espacios.m),
            for (final seccion in seccionesAyuda) ...[
              Padding(
                padding: const EdgeInsets.only(
                  top: Espacios.m,
                  bottom: Espacios.s,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    seccion.titulo,
                    style: tema.textTheme.titleSmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              for (final pregunta in seccion.preguntas)
                Padding(
                  padding: const EdgeInsets.only(bottom: Espacios.s),
                  child: _Pregunta(
                    pregunta: pregunta,
                    alReportar: () => _reportar(context),
                  ),
                ),
            ],
            const SizedBox(height: Espacios.xl),
            FilledButton(
              onPressed: () => _reportar(context),
              child: const Text(MensajesAyuda.botonReportar),
            ),
            const SizedBox(height: Espacios.xl),
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
    final tema = Theme.of(context);
    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: Espacios.l),
        childrenPadding: const EdgeInsets.fromLTRB(
          Espacios.l,
          0,
          Espacios.l,
          Espacios.l,
        ),
        expandedAlignment: Alignment.centerLeft,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(pregunta.pregunta, style: tema.textTheme.titleSmall),
        children: [
          Text(pregunta.respuesta, style: tema.textTheme.bodyMedium),
          if (pregunta.ofreceReportar) ...[
            const SizedBox(height: Espacios.m),
            OutlinedButton(
              onPressed: alReportar,
              child: const Text(MensajesAyuda.botonReportar),
            ),
          ],
        ],
      ),
    );
  }
}
