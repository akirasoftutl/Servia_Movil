import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/etiqueta_estado.dart';
import '../../auth/data/auth_service.dart';
import '../../negocios/formatos.dart';
import '../data/detalle_reserva.dart';
import '../data/reservas_service.dart';
import '../fechas_reserva.dart';
import '../mensajes.dart';
import 'mis_reservas_page.dart';

/// MVP-20, RN-45: consulta el detalle propio usando únicamente su id.
class DetalleReservaPage extends StatefulWidget {
  const DetalleReservaPage({
    super.key,
    required this.id,
    this.authService,
    this.reservasService,
    this.ahora,
  });
  final String id;
  final AuthService? authService;
  final ReservasService? reservasService;
  final DateTime Function()? ahora;

  @override
  State<DetalleReservaPage> createState() => _DetalleReservaPageState();
}

class _DetalleReservaPageState extends State<DetalleReservaPage> {
  late final AuthService _auth;
  late final ReservasService _reservas;
  DetalleReserva? _reserva;
  Object? _error;
  bool _cargando = true;
  int _version = 0;
  bool _enviando = false;
  bool _dialogoAbierto = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _reservas = widget.reservasService ?? ReservasService();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant DetalleReservaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _cargar();
  }

  Future<String> _token() async {
    try {
      final token = await _auth.usuarioActual?.getIdToken();
      if (token != null) return token;
    } on FirebaseAuthException {
      // La consulta usa el mismo mensaje cuando el token no se puede renovar.
    }
    throw const ApiException(401, MensajesReservas.sesionVencidaConsulta);
  }

  Future<void> _cargar() async {
    final version = ++_version;
    setState(() {
      _cargando = true;
      _error = null;
      _reserva = null;
    });
    try {
      final token = await _token();
      final reserva = await _reservas.obtenerMia(token, widget.id);
      if (!mounted || version != _version) return;
      setState(() {
        _reserva = reserva;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted || version != _version) return;
      setState(() {
        _error = error;
        _cargando = false;
      });
    }
  }

  Future<void> _cancelar() async {
    if (_enviando || _dialogoAbierto) return;
    final id = widget.id;
    final version = _version;
    setState(() => _dialogoAbierto = true);
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          MensajesReservas.condicionesCancelacion,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _texto,
            letterSpacing: -0.3,
          ),
        ),
        content: const SingleChildScrollView(
          child: DefaultTextStyle(
            style: TextStyle(fontSize: 14, height: 1.4, color: _textoCuerpo),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(MensajesReservas.condicionesPendiente),
                SizedBox(height: Espacios.m),
                Text(MensajesReservas.condicionesConfirmada),
                SizedBox(height: Espacios.m),
                Text(MensajesReservas.condicionesIrreversible),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(contexto, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _texto,
              side: const BorderSide(color: _bordeSecundario),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
            child: const Text(MensajesReservas.noVolver),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            style: _estiloBotonPrincipal,
            child: const Text(MensajesReservas.siCancelar),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _dialogoAbierto = false);
    if (confirmado != true || id != widget.id || version != _version) return;
    setState(() => _enviando = true);
    try {
      final token = await _token();
      await _reservas.cancelar(token, id);
      if (!mounted || id != widget.id || version != _version) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(MensajesReservas.cancelacionExitosa)),
      );
      await _cargar();
    } catch (error) {
      if (!mounted || id != widget.id || version != _version) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(MensajesReservas.mensajeDeCancelacion(error))),
      );
      if (error is ApiException && error.statusCode == 409) await _cargar();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _volverAMisReservas() {
    final navegador = Navigator.of(context);
    if (navegador.canPop()) {
      navegador.pop();
    } else {
      navegador.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              MisReservasPage(authService: _auth, reservasService: _reservas),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _encabezado(),
            const Divider(height: 1, color: _divisor),
            Expanded(
              child: _cargando
                  ? const EstadoCargando(
                      mensaje: MensajesReservas.cargandoDetalle,
                    )
                  : error != null
                  ? MensajesReservas.detalleNoEncontrado(error)
                        ? EstadoVacio(
                            icono: Icons.event_busy_outlined,
                            mensaje: MensajesReservas.reservaNoEncontrada,
                            accion: FilledButton(
                              onPressed: _volverAMisReservas,
                              style: _estiloBotonPrincipal,
                              child: const Text(
                                MensajesReservas.volverAMisReservas,
                              ),
                            ),
                          )
                        : EstadoError(
                            mensaje: MensajesReservas.mensajeDeDetalle(error),
                            onReintentar:
                                MensajesReservas.sesionInvalidaDetalle(error)
                                ? null
                                : _cargar,
                          )
                  : _datos(_reserva!),
            ),
          ],
        ),
      ),
    );
  }

  /// Cabecera propia como la del resumen de reserva del rediseño.
  Widget _encabezado() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 20, 8),
    child: Row(
      children: [
        if (Navigator.canPop(context)) ...[
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back_rounded, color: _texto, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 4),
        ] else
          const SizedBox(width: 4, height: 40),
        const Expanded(
          child: Text(
            MensajesReservas.tituloDetalle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _texto,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _datos(DetalleReserva r) {
    final textos = Theme.of(context).textTheme;
    final estado = switch (r.estado) {
      'pendiente' => MensajesReservas.estadoPendiente,
      'confirmada' => MensajesReservas.estadoConfirmada,
      'rechazada' => MensajesReservas.estadoRechazada,
      'rechazada_vencimiento' => MensajesReservas.estadoRechazadaVencimiento,
      'cancelada' => MensajesReservas.estadoCancelada,
      'completada' => MensajesReservas.estadoCompletada,
      _ => r.estado,
    };
    String disponible(String valor) =>
        valor.trim().isEmpty ? MensajesReservas.datoNoDisponible : valor;
    // RN-49/50, D4: el permiso viene de la API, sin recalcular las 24 horas.
    final accion = !r.cancelable
        ? null
        : switch (r.estado) {
            'pendiente' => MensajesReservas.retirarSolicitud,
            'confirmada' => MensajesReservas.cancelarReserva,
            _ => null,
          };
    final fueraDePlazo =
        r.estado == 'confirmada' &&
        !r.cancelable &&
        r.inicio.isAfter((widget.ahora ?? DateTime.now)());
    final tituloMotivo = switch (r.estado) {
      'rechazada' => MensajesReservas.motivoRechazo,
      'cancelada' => MensajesReservas.motivoCancelacion,
      _ => null,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, Espacios.xxl),
      children: [
        _seccion(MensajesReservas.folio, [
          SelectableText(
            r.folio,
            style: textos.headlineMedium?.copyWith(color: _texto),
          ),
          const SizedBox(height: Espacios.m),
          Align(
            alignment: Alignment.centerLeft,
            child: _InsigniaEstado(
              texto: estado,
              tono: switch (r.estado) {
                'pendiente' => TonoEstado.aviso,
                'confirmada' => TonoEstado.exito,
                _ => TonoEstado.neutro,
              },
            ),
          ),
        ]),
        _seccion(MensajesReservas.fechaYHora, [
          Text(formatearFechaLarga(fechaEnMexico(r.inicio))),
          Text(horaEnMexico(r.inicio)),
        ]),
        _seccion(MensajesReservas.servicio, [
          Text(r.servicio, style: textos.titleMedium),
          Text(
            r.duracionMin == null
                ? MensajesReservas.datoNoDisponible
                : formatearDuracion(r.duracionMin!),
          ),
          Text(
            r.precio == null
                ? MensajesReservas.datoNoDisponible
                : formatearPrecio(r.precio!),
          ),
        ]),
        _seccion(MensajesReservas.negocio, [
          Text(disponible(r.negocio), style: textos.titleMedium),
          Text(disponible(r.direccionTexto)),
          Text(disponible(r.telefono)),
        ]),
        _seccion(MensajesReservas.observacionesDetalle, [
          Text(
            r.observaciones?.trim().isNotEmpty == true
                ? r.observaciones!
                : MensajesReservas.sinObservaciones,
          ),
        ]),
        if (tituloMotivo != null && r.motivo?.trim().isNotEmpty == true)
          _seccion(tituloMotivo, [Text(r.motivo!)]),
        if (fueraDePlazo)
          const Text(
            MensajesReservas.limiteCancelacion,
            style: TextStyle(fontSize: 14, color: _textoSecundario),
          ),
        if (accion != null) ...[
          if (fueraDePlazo) const SizedBox(height: Espacios.l),
          SizedBox(
            height: 54,
            child: FilledButton(
              key: const ValueKey('cancelar-reserva'),
              onPressed: _enviando || _dialogoAbierto ? null : _cancelar,
              style: _estiloBotonPrincipal,
              child: Text(_enviando ? MensajesReservas.cancelando : accion),
            ),
          ),
        ],
      ],
    );
  }

  /// Tarjeta blanca con borde gris y sombra leve, como las de Mis reservas.
  Widget _seccion(String titulo, List<Widget> datos) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borde),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: _texto),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textoSecundario,
              ),
            ),
            const SizedBox(height: Espacios.s),
            ...datos,
          ],
        ),
      ),
    ),
  );
}

// Literales del rediseño (`mis_reservas_page.dart`,
// `resumen_reserva_page.dart`, `confirmacion_reserva_page.dart`), sin
// agregarlos al tema.
const _texto = Color(0xFF111827);
const _textoSecundario = Color(0xFF6B7280);
const _borde = Color(0xFFE5E7EB);
const _divisor = Color(0xFFF3F4F6);
const _textoCuerpo = Color(0xFF4B5563);
const _bordeSecundario = Color(0xFFD1D5DB);

/// Botón principal en píldora negra como los del rediseño.
final _estiloBotonPrincipal = FilledButton.styleFrom(
  backgroundColor: const Color(0xFF0F0F0F),
  foregroundColor: Colors.white,
  shape: const StadiumBorder(),
  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
);

/// Mismo chip de estado que la lista de Mis reservas (`_BadgeEstadoReserva`).
class _InsigniaEstado extends StatelessWidget {
  const _InsigniaEstado({required this.texto, required this.tono});

  final String texto;
  final TonoEstado tono;

  @override
  Widget build(BuildContext context) {
    final (Color fondo, Color color) = switch (tono) {
      TonoEstado.exito => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      TonoEstado.aviso => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      TonoEstado.neutro => (const Color(0xFFF3F4F6), const Color(0xFF4B5563)),
    };
    return Container(
      key: const ValueKey('estado-reserva'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
