import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/etiqueta_estado.dart';
import '../../auth/data/auth_service.dart';
import '../../reservas/fechas_reserva.dart';
import '../data/reporte.dart';
import '../data/soporte_service.dart';
import '../mensajes.dart';
import '../validaciones.dart';

/// Formulario para reportar un problema y lista de los reportes ya enviados
/// por la cuenta (HU-C115 a HU-C117, T17). Usa `POST /soporte/reportes` y
/// `GET /soporte/reportes/mios`; la API valida de verdad, aquí solo se da el
/// aviso rápido.
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
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(MensajesAyuda.tituloReportar)),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: Espacios.pantalla,
          children: [
            Text(MensajesAyuda.introReportar, style: tema.textTheme.bodyLarge),
            const SizedBox(height: Espacios.l),
            _formulario(),
            const SizedBox(height: Espacios.xl),
            Semantics(
              header: true,
              child: Text(
                MensajesAyuda.misReportes,
                style: tema.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: Espacios.m),
            _seccionLista(),
            const SizedBox(height: Espacios.xl),
          ],
        ),
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
          TextFormField(
            key: const Key('campo-asunto'),
            controller: _asunto,
            enabled: !_enviando,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            validator: validarAsunto,
            onChanged: _alEscribir,
            decoration: InputDecoration(
              helperText: MensajesAyuda.ayudaAsunto,
              helperMaxLines: 2,
              counterText: '${_asunto.text.trim().length}/$asuntoMax',
            ),
          ),
          const SizedBox(height: Espacios.l),
          const EtiquetaCampo(MensajesAyuda.etiquetaDescripcion),
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
            decoration: InputDecoration(
              helperText: MensajesAyuda.ayudaDescripcion,
              helperMaxLines: 2,
              alignLabelWithHint: true,
              counterText: '${_descripcion.text.trim().length}/$descripcionMax',
            ),
          ),
          if (_enviado) ...[
            const SizedBox(height: Espacios.l),
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
            const SizedBox(height: Espacios.l),
            Aviso(texto: errorEnvio),
          ],
          const SizedBox(height: Espacios.l),
          FilledButton(
            key: const Key('boton-enviar-reporte'),
            onPressed: _enviando ? null : _enviar,
            child: Text(
              _enviando ? MensajesAyuda.enviando : MensajesAyuda.enviar,
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
                padding: const EdgeInsets.only(bottom: Espacios.s),
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
    final tema = Theme.of(context);
    // Fecha y hora de la Ciudad de México, nunca la zona del teléfono.
    final fecha =
        '${formatearFechaLarga(fechaEnMexico(reporte.creadaEn))} · '
        '${horaEnMexico(reporte.creadaEn)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Espacios.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reporte.asunto, style: tema.textTheme.titleSmall),
            const SizedBox(height: Espacios.xs),
            Text(fecha, style: tema.textTheme.bodySmall),
            const SizedBox(height: Espacios.s),
            const EtiquetaEstado(
              texto: MensajesAyuda.etiquetaAbierto,
              tono: TonoEstado.aviso,
            ),
          ],
        ),
      ),
    );
  }
}
