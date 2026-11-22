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
  });
  final String id;
  final AuthService? authService;
  final ReservasService? reservasService;

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
      appBar: AppBar(title: const Text(MensajesReservas.tituloDetalle)),
      body: SafeArea(
        child: _cargando
            ? const EstadoCargando(mensaje: MensajesReservas.cargandoDetalle)
            : error != null
            ? MensajesReservas.detalleNoEncontrado(error)
                  ? EstadoVacio(
                      icono: Icons.event_busy_outlined,
                      mensaje: MensajesReservas.reservaNoEncontrada,
                      accion: FilledButton(
                        onPressed: _volverAMisReservas,
                        child: const Text(MensajesReservas.volverAMisReservas),
                      ),
                    )
                  : EstadoError(mensaje: MensajesReservas.errorDetalle)
            : _datos(_reserva!),
      ),
    );
  }

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
    final tituloMotivo = switch (r.estado) {
      'rechazada' => MensajesReservas.motivoRechazo,
      'cancelada' => MensajesReservas.motivoCancelacion,
      _ => null,
    };
    return ListView(
      padding: Espacios.pantalla,
      children: [
        _seccion(MensajesReservas.folio, [
          SelectableText(r.folio, style: textos.headlineMedium),
          const SizedBox(height: Espacios.m),
          Align(
            alignment: Alignment.centerLeft,
            child: EtiquetaEstado(
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
      ],
    );
  }

  Widget _seccion(String titulo, List<Widget> datos) => Padding(
    padding: const EdgeInsets.only(bottom: Espacios.l),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(Espacios.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Espacios.s),
            ...datos,
          ],
        ),
      ),
    ),
  );
}
