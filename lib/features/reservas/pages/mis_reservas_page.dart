import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/etiqueta_estado.dart';
import '../../auth/data/auth_service.dart';
import '../data/reserva_resumen.dart';
import '../data/reservas_service.dart';
import '../fechas_reserva.dart';
import '../mensajes.dart';

/// Mis reservas (MVP-19): «Próximas» e «Historial» desde `GET /reservas/mias`.
class MisReservasPage extends StatefulWidget {
  const MisReservasPage({super.key, this.authService, this.reservasService});

  final AuthService? authService;
  final ReservasService? reservasService;

  @override
  State<MisReservasPage> createState() => _MisReservasPageState();
}

class _MisReservasPageState extends State<MisReservasPage>
    with SingleTickerProviderStateMixin {
  late final AuthService _auth;
  late final ReservasService _reservas;
  late final TabController _controller;
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _reservas = widget.reservasService ?? ReservasService();
    _controller = TabController(length: 2, vsync: this);
    _controller.addListener(_alCambiarPestana);
  }

  @override
  void dispose() {
    _controller.removeListener(_alCambiarPestana);
    _controller.dispose();
    super.dispose();
  }

  void _alCambiarPestana() {
    if (_controller.index != _indice) {
      setState(() => _indice = _controller.index);
    }
  }

  Future<String> _token() async {
    final token = await _auth.usuarioActual?.getIdToken();
    if (token == null) throw const ApiException(401, 'Sin sesión.');
    return token;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(MensajesReservas.tituloMisReservas),
      bottom: TabBar(
        controller: _controller,
        tabs: const [
          Tab(text: MensajesReservas.tabProximas),
          Tab(text: MensajesReservas.tabHistorial),
        ],
      ),
    ),
    body: TabBarView(
      controller: _controller,
      children: [
        _ListaReservas(
          vista: 'proximas',
          activa: _indice == 0,
          reservasService: _reservas,
          token: _token,
        ),
        _ListaReservas(
          vista: 'historial',
          activa: _indice == 1,
          reservasService: _reservas,
          token: _token,
        ),
      ],
    ),
  );
}

enum _EstadoLista { cargando, lista, error }

class _ListaReservas extends StatefulWidget {
  const _ListaReservas({
    required this.vista,
    required this.activa,
    required this.reservasService,
    required this.token,
  });

  /// `proximas` u `historial`, tal como lo espera la API.
  final String vista;
  final bool activa;
  final ReservasService reservasService;
  final Future<String> Function() token;

  @override
  State<_ListaReservas> createState() => _ListaReservasState();
}

class _ListaReservasState extends State<_ListaReservas>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _items = <ReservaResumen>[];
  String? _siguiente;
  Object? _error;
  _EstadoLista _estado = _EstadoLista.cargando;
  bool _cargandoMas = false;
  bool _cargado = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    // Solo consulta la pestaña visible; la otra carga al abrirse por primera vez.
    if (widget.activa) _cargar();
  }

  @override
  void didUpdateWidget(covariant _ListaReservas anterior) {
    super.didUpdateWidget(anterior);
    if (widget.activa &&
        !anterior.activa &&
        !_cargado &&
        _error == null &&
        !_cargandoMas) {
      _cargar();
    }
  }

  Future<void> _cargar({bool siguientePagina = false}) async {
    if (_cargandoMas || (siguientePagina && _siguiente == null)) return;
    final version = ++_version;
    setState(() {
      _error = null;
      _cargandoMas = siguientePagina;
      if (!siguientePagina || _items.isEmpty) _estado = _EstadoLista.cargando;
    });
    try {
      final pagina = await widget.reservasService.listarMias(
        await widget.token(),
        vista: widget.vista,
        cursor: siguientePagina ? _siguiente : null,
      );
      if (!mounted || version != _version) return;
      setState(() {
        if (!siguientePagina) _items.clear();
        _items.addAll(pagina.items);
        _siguiente = pagina.siguiente;
        _cargandoMas = false;
        _cargado = true;
        _estado = _EstadoLista.lista;
      });
    } catch (error) {
      if (!mounted || version != _version) return;
      setState(() {
        _error = error;
        _cargandoMas = false;
        if (!siguientePagina || _items.isEmpty) {
          _estado = _EstadoLista.error;
        }
      });
    }
  }

  String get _mensajeVacio => widget.vista == 'proximas'
      ? MensajesReservas.sinReservasProximas
      : MensajesReservas.sinReservasHistorial;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    switch (_estado) {
      case _EstadoLista.cargando:
        return const EstadoCargando(mensaje: MensajesReservas.cargandoReservas);
      case _EstadoLista.error:
        return EstadoError(
          mensaje: MensajesReservas.mensajeDeListado(_error!),
          onReintentar: MensajesReservas.puedeReintentarListado(_error!)
              ? () => _cargar()
              : null,
        );
      case _EstadoLista.lista:
        if (_items.isEmpty) {
          return EstadoVacio(icono: Icons.event_note, mensaje: _mensajeVacio);
        }
        final conPie = _siguiente != null || _error != null;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            Espacios.l,
            Espacios.s,
            Espacios.l,
            Espacios.xl,
          ),
          itemCount: _items.length + (conPie ? 1 : 0),
          itemBuilder: (context, indice) {
            if (indice == _items.length) return _pie();
            return Padding(
              padding: const EdgeInsets.only(bottom: Espacios.m),
              child: _TarjetaReserva(reserva: _items[indice]),
            );
          },
        );
    }
  }

  Widget _pie() {
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Espacios.m),
        child: EstadoError(
          compacto: true,
          mensaje: MensajesReservas.mensajeDeListado(error),
          onReintentar: MensajesReservas.puedeReintentarListado(error)
              ? () => _cargar(siguientePagina: true)
              : null,
        ),
      );
    }
    if (_siguiente == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espacios.m),
      child: Center(
        child: TextButton(
          onPressed: _cargandoMas ? null : () => _cargar(siguientePagina: true),
          child: Text(
            _cargandoMas
                ? MensajesReservas.cargando
                : MensajesReservas.cargarMas,
          ),
        ),
      ),
    );
  }
}

class _TarjetaReserva extends StatelessWidget {
  const _TarjetaReserva({required this.reserva});

  final ReservaResumen reserva;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fecha = formatearFechaLarga(fechaEnMexico(reserva.inicio));
    final hora = horaEnMexico(reserva.inicio);
    return Card(
      child: InkWell(
        // MVP-20: al existir el detalle, navegar con `reserva.id` desde aquí.
        onTap: null,
        borderRadius: Radios.tarjeta,
        child: Padding(
          padding: const EdgeInsets.all(Espacios.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      reserva.negocio,
                      style: tema.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: Espacios.s),
                  EtiquetaEstado(
                    texto: _textoEstado(reserva.estado),
                    tono: _tonoEstado(reserva.estado),
                  ),
                ],
              ),
              const SizedBox(height: Espacios.s),
              Text(reserva.servicio, style: tema.textTheme.bodyMedium),
              const SizedBox(height: Espacios.xs),
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 16,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Espacios.xs),
                  Expanded(
                    child: Text(
                      '$fecha · $hora',
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _textoEstado(String estado) => switch (estado) {
  'pendiente' => MensajesReservas.estadoPendiente,
  'confirmada' => MensajesReservas.estadoConfirmada,
  'rechazada' => MensajesReservas.estadoRechazada,
  'rechazada_vencimiento' => MensajesReservas.estadoRechazadaVencimiento,
  'cancelada' => MensajesReservas.estadoCancelada,
  'completada' => MensajesReservas.estadoCompletada,
  _ => estado,
};

TonoEstado _tonoEstado(String estado) => switch (estado) {
  'pendiente' => TonoEstado.aviso,
  'confirmada' => TonoEstado.exito,
  _ => TonoEstado.neutro,
};
