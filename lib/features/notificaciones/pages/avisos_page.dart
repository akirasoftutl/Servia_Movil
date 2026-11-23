import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/data/auth_service.dart';
import '../data/aviso.dart';
import '../data/notificaciones_service.dart';
import '../data/servicio_push.dart';
import '../mensajes.dart';

/// Lista de avisos de reservas del cliente (MVP-28).
class AvisosPage extends StatefulWidget {
  const AvisosPage({
    super.key,
    this.authService,
    this.notificacionesService,
    this.push,
  });

  final AuthService? authService;
  final NotificacionesService? notificacionesService;
  final ServicioPush? push;

  @override
  State<AvisosPage> createState() => _AvisosPageState();
}

enum _EstadoLista { cargando, lista, error }

class _AvisosPageState extends State<AvisosPage> {
  late final AuthService _auth;
  late final NotificacionesService _servicio;
  late final ServicioPush _push;
  late final ScrollController _controller;

  final List<Aviso> _avisos = [];
  String? _siguiente;
  Object? _error;
  _EstadoLista _estado = _EstadoLista.cargando;
  bool _cargando = false;
  bool _cargandoMas = false;
  bool _marcando = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _servicio = widget.notificacionesService ?? NotificacionesService();
    _push = widget.push ?? ServicioPush.instancia;
    _controller = ScrollController()..addListener(_alDesplazarse);
    _cargar();
  }

  @override
  void dispose() {
    _controller.removeListener(_alDesplazarse);
    _controller.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await _auth.usuarioActual?.getIdToken();
    if (token == null) {
      throw const ApiException(401, MensajesNotificaciones.errorCarga);
    }
    return token;
  }

  Future<void> _cargar({bool siguientePagina = false}) async {
    if (_cargando ||
        _cargandoMas ||
        (siguientePagina && _siguiente == null)) {
      return;
    }
    final version = ++_version;
    setState(() {
      _error = null;
      _cargando = !siguientePagina;
      _cargandoMas = siguientePagina;
      if (!siguientePagina || _avisos.isEmpty) {
        _estado = _EstadoLista.cargando;
      }
    });
    try {
      final pagina = await _servicio.listar(
        await _token(),
        cursor: siguientePagina ? _siguiente : null,
      );
      if (!mounted || version != _version) return;
      setState(() {
        if (!siguientePagina) _avisos.clear();
        _avisos.addAll(pagina.items);
        _avisos.sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
        _siguiente = pagina.siguiente;
        _push.sincronizarNoLeidas(pagina.noLeidas);
        _cargando = false;
        _cargandoMas = false;
        _estado = _EstadoLista.lista;
      });
    } catch (error) {
      if (!mounted || version != _version) return;
      setState(() {
        _error = error;
        _cargando = false;
        _cargandoMas = false;
        if (!siguientePagina || _avisos.isEmpty) {
          _estado = _EstadoLista.error;
        }
      });
    }
  }

  void _alDesplazarse() {
    if (!_controller.hasClients || _siguiente == null) return;
    if (_controller.position.extentAfter < 200) {
      _cargar(siguientePagina: true);
    }
  }

  Future<void> _abrir(Aviso aviso) async {
    if (_marcando) return;
    _marcando = true;
    final navegador = Navigator.of(context);
    try {
      await _servicio.marcarLeida(await _token(), aviso.id);
      if (!mounted) return;
      final indice = _avisos.indexWhere((item) => item.id == aviso.id);
      if (indice != -1) {
        setState(() => _avisos[indice] = aviso.conLeida(true));
      }
      _push.marcarLeidaLocal();
    } catch (_) {
      // Aun con error de red se abre el detalle: ya se intentó marcar la lectura.
    } finally {
      _marcando = false;
    }
    final reservaId = aviso.reservaId;
    if (reservaId != null && reservaId.isNotEmpty) {
      await navegador.pushNamed('/reservas/$reservaId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        title: const Text(MensajesNotificaciones.titulo),
      ),
      body: SafeArea(
        bottom: false,
        child: switch (_estado) {
          _EstadoLista.cargando => const EstadoCargando(
              mensaje: MensajesNotificaciones.cargando,
            ),
          _EstadoLista.error => EstadoError(
              mensaje: MensajesNotificaciones.errorCarga,
              onReintentar: () => _cargar(),
            ),
          _EstadoLista.lista => _avisos.isEmpty
              ? const EstadoVacio(
                  icono: Icons.notifications_none,
                  mensaje: MensajesNotificaciones.sinAvisos,
                )
              : _lista(),
        },
      ),
    );
  }

  Widget _lista() {
    final conPie = _siguiente != null || _error != null;
    return ListView.builder(
      controller: _controller,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, Espacios.xl),
      itemCount: _avisos.length + (conPie ? 1 : 0),
      itemBuilder: (context, indice) {
        if (indice == _avisos.length) return _pie();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _TarjetaAviso(aviso: _avisos[indice], alAbrir: _abrir),
        );
      },
    );
  }

  Widget _pie() {
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Espacios.m),
        child: EstadoError(
          compacto: true,
          mensaje: MensajesNotificaciones.errorCarga,
          onReintentar: () => _cargar(siguientePagina: true),
        ),
      );
    }
    if (_siguiente == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Espacios.m),
      child: Center(
        child: _cargandoMas
            ? const Padding(
                padding: EdgeInsets.all(Espacios.m),
                child: EstadoCargando(compacto: true),
              )
            : OutlinedButton(
                onPressed: () => _cargar(siguientePagina: true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: const StadiumBorder(),
                ),
                child: const Text(MensajesNotificaciones.cargarMas),
              ),
      ),
    );
  }
}

class _TarjetaAviso extends StatelessWidget {
  const _TarjetaAviso({required this.aviso, required this.alAbrir});

  final Aviso aviso;
  final Future<void> Function(Aviso) alAbrir;

  @override
  Widget build(BuildContext context) {
    final fecha = formatearFechaAviso(aviso.creadaEn);
    final peso = aviso.leida ? FontWeight.w500 : FontWeight.w700;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => alAbrir(aviso),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      aviso.titulo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: peso,
                        color: const Color(0xFF111827),
                      ),
                    ),
                  ),
                  if (!aviso.leida)
                    Semantics(
                      label: MensajesNotificaciones.noLeida,
                      child: Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6, left: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF7C3AED),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                aviso.cuerpo,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: peso,
                  color: const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                fecha,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
