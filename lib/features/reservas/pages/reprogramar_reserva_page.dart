import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/data/auth_service.dart';
import '../../negocios/data/disponibilidad.dart';
import '../../negocios/data/disponibilidad_service.dart';
import '../../negocios/data/negocios_service.dart';
import '../../negocios/data/servicio.dart';
import '../../negocios/formatos.dart';
import '../../negocios/pages/disponibilidad_page.dart';
import '../data/detalle_reserva.dart';
import '../data/reservas_service.dart';
import '../fechas_reserva.dart';
import '../mensajes.dart';
import '../resultado_reprogramacion.dart';
import 'lista_servicios_cambio.dart';
import 'resumen_cambio_reserva.dart';

/// Cambiar la fecha, la hora o el servicio de una reserva propia (T18, T19;
/// HU-C71 a HU-C73). La API decide si se puede y deja la reserva Pendiente:
/// aquí solo se elige, se resume y se envía. Al cerrar devuelve un
/// [ResultadoReprogramacion] (o nada si el cliente salió sin cambiar).
class ReprogramarReservaPage extends StatefulWidget {
  const ReprogramarReservaPage({
    super.key,
    required this.reserva,
    this.authService,
    this.reservasService,
    this.negociosService,
    this.disponibilidadService,
    this.ahora,
  });

  final DetalleReserva reserva;
  final AuthService? authService;
  final ReservasService? reservasService;
  final NegociosService? negociosService;
  final DisponibilidadService? disponibilidadService;
  final DateTime Function()? ahora;

  @override
  State<ReprogramarReservaPage> createState() => _ReprogramarReservaPageState();
}

class _ReprogramarReservaPageState extends State<ReprogramarReservaPage> {
  late final AuthService _auth;
  late final ReservasService _reservas;
  late final NegociosService _negocios;
  late final DisponibilidadService _disponibilidad;

  Servicio? _servicioNuevo;
  bool _verServicios = false;
  bool _cargandoServicios = false;
  List<Servicio>? _servicios;
  Object? _errorServicios;

  SeleccionDisponibilidad? _seleccion;
  bool _eligiendo = false;
  bool _enviando = false;
  String? _aviso;

  DetalleReserva get _reserva => widget.reserva;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _reservas = widget.reservasService ?? ReservasService();
    _negocios = widget.negociosService ?? NegociosService();
    _disponibilidad = widget.disponibilidadService ?? DisponibilidadService();
  }

  Future<String> _token() async {
    try {
      final token = await _auth.usuarioActual?.getIdToken();
      if (token != null) return token;
    } on FirebaseAuthException {
      // Mismo mensaje que el resto de la app cuando el token no se renueva.
    }
    throw const ApiException(401, MensajesReservas.sesionVencidaConsulta);
  }

  // Servicio con el que se cambia: el elegido o el de la reserva.
  String get _servicioId => _servicioNuevo?.id ?? _reserva.servicioId;
  String get _servicioNombre => _servicioNuevo?.nombre ?? _reserva.servicio;
  num? get _precio => _servicioNuevo?.precio ?? _reserva.precio;
  int? get _duracion => _servicioNuevo?.duracionMin ?? _reserva.duracionMin;

  /// Solo se manda `servicioId` si cambió; si no, la API usa el de la reserva.
  String? get _servicioIdCambiado =>
      _servicioId == _reserva.servicioId ? null : _servicioId;

  static String _detalle(int? duracion, num? precio) =>
      '${duracion == null ? MensajesReservas.datoNoDisponible : formatearDuracion(duracion)}'
      ' · '
      '${precio == null ? MensajesReservas.datoNoDisponible : formatearPrecio(precio)}';

  Future<void> _cargarServicios() async {
    setState(() {
      _cargandoServicios = true;
      _errorServicios = null;
    });
    try {
      final servicios = await _negocios.obtenerServicios(_reserva.negocioId);
      if (!mounted) return;
      setState(() {
        _servicios = servicios;
        _cargandoServicios = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorServicios = error;
        _cargandoServicios = false;
      });
    }
  }

  void _alternarServicios() {
    setState(() => _verServicios = !_verServicios);
    if (_verServicios && _servicios == null && !_cargandoServicios) {
      _cargarServicios();
    }
  }

  void _elegirServicio(Servicio servicio) => setState(() {
    _servicioNuevo = servicio.id == _reserva.servicioId ? null : servicio;
    _verServicios = false;
  });

  Future<void> _elegirHorario({String? aviso}) async {
    if (_enviando || _eligiendo) return;
    setState(() {
      _eligiendo = true;
      _aviso = null;
    });
    final cambiado = _servicioIdCambiado;
    final seleccion = await Navigator.push<SeleccionDisponibilidad>(
      context,
      MaterialPageRoute(
        builder: (_) => DisponibilidadPage(
          negocioId: _reserva.negocioId,
          servicioId: _servicioId,
          service: widget.disponibilidadService,
          ahora: widget.ahora ?? DateTime.now,
          aviso: aviso,
          cargarDias: () async => _disponibilidad.obtenerDiasDeReserva(
            await _token(),
            _reserva.id,
            servicioId: cambiado,
          ),
          cargarHoras: (fecha) async => _disponibilidad.obtenerHorasDeReserva(
            await _token(),
            _reserva.id,
            fecha,
            servicioId: cambiado,
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _eligiendo = false;
      if (seleccion != null) _seleccion = seleccion;
    });
  }

  Future<void> _enviar() async {
    final seleccion = _seleccion;
    if (seleccion == null || _enviando) return;
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      final token = await _token();
      final resultado = await _reservas.reprogramar(
        token,
        _reserva.id,
        inicioIsoConZona(seleccion.fecha, seleccion.hora),
        servicioId: _servicioIdCambiado,
      );
      if (!mounted) return;
      Navigator.pop(context, ResultadoReprogramacion.reprogramada(resultado));
    } catch (error) {
      if (!mounted) return;
      await _alFallar(error);
    }
  }

  Future<void> _alFallar(Object error) async {
    final mensaje = MensajesReservas.mensajeDeReprogramacion(error);
    if (error is ApiException && error.statusCode == 404) {
      Navigator.pop(context, ResultadoReprogramacion.noDisponible(mensaje));
      return;
    }
    if (error is ApiException && error.statusCode == 409) {
      // O el horario se ocupó, o la reserva ya no se puede cambiar: se vuelve
      // a leer para saber cuál (la regla es de la API, no de la app).
      DetalleReserva? actual;
      try {
        actual = await _reservas.obtenerMia(await _token(), _reserva.id);
      } catch (_) {
        actual = null;
      }
      if (!mounted) return;
      if (actual != null && !actual.reprogramable) {
        Navigator.pop(
          context,
          ResultadoReprogramacion.noReprogramable(mensaje),
        );
        return;
      }
      setState(() {
        _enviando = false;
        _seleccion = null;
      });
      await _elegirHorario(aviso: mensaje);
      return;
    }
    setState(() {
      _enviando = false;
      _aviso = mensaje;
    });
  }

  CitaResumen _citaActual() => CitaResumen(
    fecha: formatearFechaLarga(fechaEnMexico(_reserva.inicio)),
    hora: horaEnMexico(_reserva.inicio),
  );

  @override
  Widget build(BuildContext context) {
    final seleccion = _seleccion;
    return PopScope(
      canPop: !_enviando,
      child: Scaffold(
        appBar: AppBar(title: const Text(MensajesReservas.tituloReprogramar)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Espacios.l),
            children: [
              if (_aviso != null) ...[
                Aviso(texto: _aviso!),
                const SizedBox(height: Espacios.l),
              ],
              if (seleccion == null)
                ..._seleccionar(context)
              else
                ..._resumen(seleccion),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _seleccionar(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final suave = Theme.of(context).colorScheme.onSurfaceVariant;
    final cita = _citaActual();
    final hasta = _reserva.reprogramableHasta;
    return [
      Card(
        key: const ValueKey('tarjeta-cita-actual'),
        child: Padding(
          padding: const EdgeInsets.all(Espacios.l),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MensajesReservas.citaActual,
                  style: textos.labelMedium?.copyWith(color: suave),
                ),
                const SizedBox(height: Espacios.xs),
                Text(cita.fecha, style: textos.titleMedium),
                Text(cita.hora, style: textos.bodyLarge),
              ],
            ),
          ),
        ),
      ),
      if (_reserva.estado == 'confirmada' && hasta != null) ...[
        const SizedBox(height: Espacios.m),
        Text(
          '${MensajesReservas.puedesCambiarHasta} '
          '${formatearFechaLarga(fechaEnMexico(hasta))} '
          'a las ${horaEnMexico(hasta)}.',
          style: textos.bodySmall?.copyWith(color: suave),
        ),
      ],
      const SizedBox(height: Espacios.m),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(Espacios.l),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  MensajesReservas.servicioElegido,
                  style: textos.labelMedium?.copyWith(color: suave),
                ),
                const SizedBox(height: Espacios.xs),
                Text(_servicioNombre, style: textos.titleMedium),
                Text(_detalle(_duracion, _precio), style: textos.bodyMedium),
                const SizedBox(height: Espacios.s),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('cambiar-servicio'),
                    onPressed: _alternarServicios,
                    child: Text(
                      _verServicios
                          ? MensajesReservas.ocultarServicios
                          : MensajesReservas.cambiarDeServicio,
                    ),
                  ),
                ),
                if (_verServicios) _listaServicios(),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: Espacios.xl),
      FilledButton(
        key: const ValueKey('elegir-horario'),
        onPressed: _eligiendo ? null : _elegirHorario,
        child: const Text(MensajesReservas.elegirFechaHora),
      ),
    ];
  }

  Widget _listaServicios() {
    if (_cargandoServicios) {
      return const EstadoCargando(
        compacto: true,
        mensaje: MensajesReservas.cargandoServicios,
      );
    }
    if (_errorServicios != null) {
      return EstadoError(
        compacto: true,
        mensaje: MensajesReservas.errorServicios,
        onReintentar: _cargarServicios,
      );
    }
    final servicios = _servicios ?? const <Servicio>[];
    if (servicios.isEmpty) {
      return const EstadoVacio(
        compacto: true,
        icono: Icons.content_cut_outlined,
        mensaje: MensajesReservas.sinOtrosServicios,
      );
    }
    return ListaServiciosCambio(
      servicios: servicios,
      servicioIdActual: _servicioId,
      onElegir: _elegirServicio,
    );
  }

  List<Widget> _resumen(SeleccionDisponibilidad seleccion) {
    final cambioServicio = _servicioIdCambiado != null;
    return [
      ResumenCambioReserva(
        actual: _citaActual(),
        nueva: CitaResumen(
          fecha: formatearFechaLarga(seleccion.fecha),
          hora: seleccion.hora,
        ),
        servicio: _servicioNombre,
        detalleServicio: _detalle(_duracion, _precio),
        servicioAntes: cambioServicio
            ? '${_reserva.servicio} · '
                  '${_detalle(_reserva.duracionMin, _reserva.precio)}'
            : null,
      ),
      const SizedBox(height: Espacios.l),
      const Aviso(
        texto: MensajesReservas.avisoVuelvePendiente,
        tipo: TipoAviso.informacion,
      ),
      const SizedBox(height: Espacios.xl),
      FilledButton(
        key: const ValueKey('confirmar-cambio'),
        onPressed: _enviando ? null : _enviar,
        child: Text(
          _enviando
              ? MensajesReservas.reprogramando
              : MensajesReservas.siCambiar,
        ),
      ),
      const SizedBox(height: Espacios.m),
      OutlinedButton(
        key: const ValueKey('volver-del-resumen'),
        onPressed: _enviando ? null : () => setState(() => _seleccion = null),
        child: const Text(MensajesReservas.noVolver),
      ),
    ];
  }
}
