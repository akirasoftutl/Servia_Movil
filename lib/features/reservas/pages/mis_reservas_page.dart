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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 25, 20, 14),
              child: Text(
                MensajesReservas.tituloMisReservas,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
            ),

          
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Row(
                children: [
                  _ChipPestana(
                    texto: MensajesReservas.tabProximas,
                    seleccionada: _indice == 0,
                    onTap: () => _controller.animateTo(0),
                  ),
                  const SizedBox(width: 10),
                  _ChipPestana(
                    texto: MensajesReservas.tabHistorial,
                    seleccionada: _indice == 1,
                    onTap: () => _controller.animateTo(1),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            // Contenido de cada pestaña
            Expanded(
              child: TabBarView(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipPestana extends StatelessWidget {
  const _ChipPestana({
    required this.texto,
    required this.seleccionada,
    required this.onTap,
  });

  final String texto;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionada ? const Color(0xFF0F0F0F) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: seleccionada
                ? const Color(0xFF0F0F0F)
                : const Color(0xFFD1D5DB),
            width: 1,
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: seleccionada ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }
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
    if (widget.activa && !anterior.activa) {
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
          return EstadoVacio(
            icono: Icons.calendar_today_outlined,
            mensaje: _mensajeVacio,
          );
        }
        final conPie = _siguiente != null || _error != null;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, Espacios.xl),
          itemCount: _items.length + (conPie ? 1 : 0),
          itemBuilder: (context, indice) {
            if (indice == _items.length) return _pie();
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
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
        child: OutlinedButton(
          onPressed: _cargandoMas ? null : () => _cargar(siguientePagina: true),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            _cargandoMas
                ? MensajesReservas.cargando
                : MensajesReservas.cargarMas,
            style: const TextStyle(fontWeight: FontWeight.w600),
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
    final fecha = formatearFechaLarga(fechaEnMexico(reserva.inicio));
    final hora = horaEnMexico(reserva.inicio);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        // MVP-20: al existir el detalle, navegar con `reserva.id` desde aquí.
        onTap: null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera: Ícono de negocio + Nombre + Badge de estado
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF7C3AED),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reserva.negocio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          reserva.servicio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _BadgeEstadoReserva(
                    texto: _textoEstado(reserva.estado),
                    tono: _tonoEstado(reserva.estado),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Bloque inferior gris claro con fecha y hora (estilo chip de ubicación/horario de la app)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: Color(0xFF111827),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fecha,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hora,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeEstadoReserva extends StatelessWidget {
  const _BadgeEstadoReserva({
    required this.texto,
    required this.tono,
  });

  final String texto;
  final TonoEstado tono;

  @override
  Widget build(BuildContext context) {
    final (Color fondo, Color textoColor) = switch (tono) {
      TonoEstado.exito => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      TonoEstado.aviso => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      TonoEstado.neutro => (const Color(0xFFF3F4F6), const Color(0xFF4B5563)),
    };

    return Container(
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
          color: textoColor,
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