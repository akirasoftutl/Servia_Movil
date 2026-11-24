import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/data/auth_service.dart';
import '../../reservas/fechas_reserva.dart';
import '../data/reporte.dart';
import '../data/soporte_service.dart';
import '../mensajes.dart';
import '../validaciones.dart';

class ReportarProblemaPage extends StatefulWidget {
  const ReportarProblemaPage({
    super.key,
    this.authService,
    this.soporteService,
  });

  final AuthService? authService;
  final SoporteService? soporteService;

  @override
  State<ReportarProblemaPage> createState() => _ReportarProblemaPageState();
}

enum _EstadoLista { cargando, lista, error }

/// La API devuelve como máximo los últimos 50 (LIMITE_REPORTES_MIOS).
const _maxReportes = 50;

class _ReportarProblemaPageState extends State<ReportarProblemaPage> {
  final _formKey = GlobalKey<FormState>();
  final _asunto = TextEditingController();
  final _descripcion = TextEditingController();

  late final AuthService _auth;
  late final SoporteService _soporte;

  bool _validarAlEscribir = false;
  bool _enviando = false;
  bool _enviado = false;
  String? _errorEnvio;

  _EstadoLista _estadoLista = _EstadoLista.cargando;
  List<Reporte> _reportes = const [];
  Object? _errorLista;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _soporte = widget.soporteService ?? SoporteService();
    _cargarLista();
  }

  @override
  void dispose() {
    _asunto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await _auth.usuarioActual?.getIdToken();
    if (token == null) {
      throw const ApiException(401, MensajesAyuda.sesionVencida);
    }
    return token;
  }

  Future<void> _cargarLista() async {
    final version = ++_version;
    setState(() {
      _estadoLista = _EstadoLista.cargando;
      _errorLista = null;
    });
    try {
      final reportes = await _soporte.listarMios(await _token());
      if (!mounted || version != _version) return;
      setState(() {
        _reportes = reportes;
        _estadoLista = _EstadoLista.lista;
      });
    } catch (error) {
      if (!mounted || version != _version) return;
      setState(() {
        _errorLista = error;
        _estadoLista = _EstadoLista.error;
      });
    }
  }

  /// Quita el aviso anterior en cuanto la persona vuelve a escribir.
  void _alEscribir(String _) {
    setState(() {
      _enviado = false;
      _errorEnvio = null;
    });
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    setState(() => _validarAlEscribir = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _enviado = false;
      _errorEnvio = null;
    });
    try {
      final nuevo = await _soporte.enviar(
        await _token(),
        asunto: _asunto.text.trim(),
        descripcion: _descripcion.text.trim(),
      );
      if (!mounted) return;
      _asunto.clear();
      _descripcion.clear();
      _formKey.currentState?.reset();
      setState(() {
        _validarAlEscribir = false;
        _enviando = false;
        _enviado = true;
        if (nuevo != null && _estadoLista == _EstadoLista.lista) {
          _reportes = [
            nuevo,
            ..._reportes.where((r) => r.id != nuevo.id),
          ].take(_maxReportes).toList();
        }
      });
      // Sin lista a la vista (cargando, con error o sin cuerpo del 201) se
      // vuelve a pedir: el reporte ya existe en la API.
      if (nuevo == null || _estadoLista != _EstadoLista.lista) _cargarLista();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException &&
          error.statusCode == 401 &&
          _auth.usuarioActual != null) {
        // El token ya no sirve: se cierra la sesión para volver a pedirla.
        await _auth.cerrarSesion();
        if (!mounted) return;
      }
      // Lo escrito se conserva para poder reintentar.
      setState(() {
        _enviando = false;
        _errorEnvio = MensajesAyuda.mensajeDeEnvio(error);
      });
    }
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
                      MensajesAyuda.tituloReportar,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: -0.4,
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
                  Text(
                    MensajesAyuda.introReportar,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF4B5563),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _formulario(),
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    header: true,
                    child: const Text(
                      MensajesAyuda.misReportes,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _seccionLista(),
                  const SizedBox(height: Espacios.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracionCampo({
    required String ayuda,
    required String contador,
    bool multiline = false,
  }) {
    final bordeBase = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
    );
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      helperText: ayuda,
      helperMaxLines: 2,
      helperStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xFF6B7280),
      ),
      counterText: contador,
      counterStyle: const TextStyle(
        fontSize: 12,
        color: Color(0xFF6B7280),
      ),
      alignLabelWithHint: multiline,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: bordeBase,
      enabledBorder: bordeBase,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0F0F0F), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFB91C1C), width: 1.5),
      ),
    );
  }

  Widget _formulario() {
    final errorEnvio = _errorEnvio;
    return Form(
      key: _formKey,
      autovalidateMode: _validarAlEscribir
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EtiquetaCampo(MensajesAyuda.etiquetaAsunto),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('campo-asunto'),
            controller: _asunto,
            enabled: !_enviando,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            validator: validarAsunto,
            onChanged: _alEscribir,
            style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
            decoration: _decoracionCampo(
              ayuda: MensajesAyuda.ayudaAsunto,
              contador: '${_asunto.text.trim().length}/$asuntoMax',
            ),
          ),
          const SizedBox(height: 18),
          const EtiquetaCampo(MensajesAyuda.etiquetaDescripcion),
          const SizedBox(height: 8),
          TextFormField(
            key: const Key('campo-descripcion'),
            controller: _descripcion,
            enabled: !_enviando,
            minLines: 4,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            validator: validarDescripcion,
            onChanged: _alEscribir,
            style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
            decoration: _decoracionCampo(
              ayuda: MensajesAyuda.ayudaDescripcion,
              contador: '${_descripcion.text.trim().length}/$descripcionMax',
              multiline: true,
            ),
          ),
          if (_enviado) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: const Aviso(
                texto: MensajesAyuda.exito,
                tipo: TipoAviso.informacion,
                icono: Icons.check_circle_outline,
              ),
            ),
          ],
          if (errorEnvio != null) ...[
            const SizedBox(height: 16),
            Aviso(texto: errorEnvio),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              key: const Key('boton-enviar-reporte'),
              onPressed: _enviando ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F0F0F),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                elevation: 0,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                _enviando ? MensajesAyuda.enviando : MensajesAyuda.enviar,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccionLista() {
    switch (_estadoLista) {
      case _EstadoLista.cargando:
        return const EstadoCargando(
          compacto: true,
          mensaje: MensajesAyuda.cargandoReportes,
        );
      case _EstadoLista.error:
        final error = _errorLista!;
        return EstadoError(
          compacto: true,
          mensaje: MensajesAyuda.mensajeDeLista(error),
          onReintentar: MensajesAyuda.puedeReintentarLista(error)
              ? _cargarLista
              : null,
        );
      case _EstadoLista.lista:
        if (_reportes.isEmpty) {
          return const EstadoVacio(
            compacto: true,
            icono: Icons.flag_outlined,
            mensaje: MensajesAyuda.sinReportes,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final reporte in _reportes)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TarjetaReporte(reporte: reporte),
              ),
          ],
        );
    }
  }
}

class _TarjetaReporte extends StatelessWidget {
  const _TarjetaReporte({required this.reporte});

  final Reporte reporte;

  @override
  Widget build(BuildContext context) {
    // Fecha y hora de la Ciudad de México, nunca la zona del teléfono.
    final fecha =
        '${formatearFechaLarga(fechaEnMexico(reporte.creadaEn))} · '
        '${horaEnMexico(reporte.creadaEn)}';
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  reporte.asunto,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  MensajesAyuda.etiquetaAbierto,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  fecha,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}