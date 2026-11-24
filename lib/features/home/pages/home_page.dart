import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../ayuda/data/soporte_service.dart';
import '../../ayuda/mensajes.dart';
import '../../ayuda/pages/ayuda_page.dart';
import '../../negocios/data/negocios_service.dart';
import '../../negocios/data/ubicacion_cliente.dart';
import '../../negocios/pages/lista_negocios_page.dart';
import '../../negocios/pages/negocios_cercanos.dart';
import '../../perfil/data/perfil_cliente_service.dart';
import '../../perfil/pages/mi_perfil_page.dart';
import '../../notificaciones/data/notificaciones_service.dart';
import '../../notificaciones/data/servicio_push.dart';
import '../../notificaciones/mensajes.dart';
import '../../reservas/data/reservas_service.dart';
import '../../reservas/pages/actividad_screen.dart';
import '../../reservas/pages/mis_reservas_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onCerrarSesion,
    this.negociosService,
    this.proveedorUbicacion,
    this.authService,
    this.perfilClienteService,
    this.soporteService,
    this.reservasService,
    this.notificacionesService,
    this.push,
    this.onSolicitarLogin,
  });

  final NegociosService? negociosService;
  final ProveedorUbicacionCliente? proveedorUbicacion;
  final AuthService? authService;
  final PerfilClienteService? perfilClienteService;
  final SoporteService? soporteService;
  final ReservasService? reservasService;
  final NotificacionesService? notificacionesService;
  final ServicioPush? push;
  final VoidCallback onCerrarSesion;
  final VoidCallback? onSolicitarLogin;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _indiceActual = 0;
  late final AuthService _auth;
  late final NotificacionesService _notificaciones;
  late final ServicioPush _push;
  late final List<Key> _clavesPantallas;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _notificaciones =
        widget.notificacionesService ?? NotificacionesService();
    _push = widget.push ?? ServicioPush();
    _clavesPantallas = List<Key>.generate(4, (_) => UniqueKey());
    if (_auth.usuarioActual != null) _cargarNoLeidas();
  }

  /// Siembra el globo con `GET /notificaciones`; los push posteriores lo
  /// actualizan directamente en [ServicioPush.noLeidas].
  Future<void> _cargarNoLeidas() async {
    final usuario = _auth.usuarioActual;
    if (usuario == null) return;
    try {
      final token = await usuario.getIdToken();
      if (token == null) return;
      final pagina = await _notificaciones.listar(token);
      if (!mounted) return;
      _push.sincronizarNoLeidas(pagina.noLeidas);
    } catch (_) {
      // Sin red se conserva el último número conocido (o cero).
    }
  }

  void _seleccionar(int nuevoIndice) {
    if (nuevoIndice == 3 && _auth.usuarioActual == null) {
      widget.onSolicitarLogin?.call();
      return;
    }

    setState(() {
      if (nuevoIndice == 2) {
        _clavesPantallas[nuevoIndice] = UniqueKey();
      }
      _indiceActual = nuevoIndice;
    });
  }

  void _abrirAyuda() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AyudaPage(
          authService: _auth,
          soporteService: widget.soporteService,
        ),
      ),
    );
  }

  String _obtenerInicialUsuario() {
    final usuario = _auth.usuarioActual;
    final nombre = usuario?.displayName?.trim() ?? '';

    if (nombre.isNotEmpty) return nombre[0].toUpperCase();

    final correo = usuario?.email?.trim() ?? '';
    if (correo.isNotEmpty) return correo[0].toUpperCase();

    return 'J';
  }

  @override
  Widget build(BuildContext context) {
    final estaLogueado = _auth.usuarioActual != null;
    final inicial = _obtenerInicialUsuario();

    final pantallas = <Widget>[
      ColoredBox(
        key: _clavesPantallas[0],
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              NegociosCercanos(
                service: widget.negociosService,
                proveedorUbicacion: widget.proveedorUbicacion,
              ),
              Expanded(
                child: ListaNegocios(negociosService: widget.negociosService),
              ),
            ],
          ),
        ),
      ),

      ListaNegocios(
        key: _clavesPantallas[1],
        negociosService: widget.negociosService,
      ),

      if (estaLogueado)
        MisReservasPage(
          key: _clavesPantallas[2],
          authService: _auth,
          reservasService: widget.reservasService,
        )
      else
        ActividadScreen(
          key: _clavesPantallas[2],
          onBuscarLugares: () => _seleccionar(0),
          onIniciarSesion: widget.onSolicitarLogin,
        ),

      if (estaLogueado)
        MiPerfilPage(
          key: _clavesPantallas[3],
          authService: _auth,
          perfilClienteService: widget.perfilClienteService,
        )
      else
        SizedBox.shrink(key: _clavesPantallas[3]),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      // La barra superior va superpuesta: así no quita espacio a las listas
      // que ya tienen su propia cabecera (Inicio, Mis reservas, Mi perfil).
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(index: _indiceActual, children: pantallas),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (estaLogueado)
                        IconButton(
                          tooltip: MensajesNotificaciones.campana,
                          onPressed: () => Navigator.of(context).pushNamed(
                            '/avisos',
                            arguments: _push,
                          ),
                          icon: _CampanaAvisos(push: _push),
                        ),
                      if (estaLogueado)
                        IconButton(
                          tooltip: MensajesAyuda.tooltipAyuda,
                          onPressed: _abrirAyuda,
                          icon: const Icon(Icons.help_outline),
                        ),
                      IconButton(
                        tooltip: MensajesNotificaciones.perfil,
                        onPressed: () => _seleccionar(3),
                        icon: const Icon(Icons.person_outline_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BarraNavegacionInferior(
        indiceActual: _indiceActual,
        inicialUsuario: inicial,
        estaLogueado: estaLogueado,
        onSeleccionar: _seleccionar,
      ),
    );
  }
}

class _BarraNavegacionInferior extends StatelessWidget {
  const _BarraNavegacionInferior({
    required this.indiceActual,
    required this.inicialUsuario,
    required this.estaLogueado,
    required this.onSeleccionar,
  });

  final int indiceActual;
  final String inicialUsuario;
  final bool estaLogueado;
  final ValueChanged<int> onSeleccionar;

  static const _colorActivo = Color(0xFF7C3AED);
  static const _colorInactivo = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              _ItemBarra(
                etiqueta: 'Inicio',
                seleccionado: indiceActual == 0,
                icono: Icon(
                  indiceActual == 0 ? Icons.home_rounded : Icons.home_outlined,
                  size: 26,
                  color: indiceActual == 0 ? _colorActivo : _colorInactivo,
                ),
                onTap: () => onSeleccionar(0),
              ),

              _ItemBarra(
                etiqueta: 'Buscar',
                seleccionado: indiceActual == 1,
                icono: Icon(
                  Icons.search_rounded,
                  size: 26,
                  color: indiceActual == 1 ? _colorActivo : _colorInactivo,
                ),
                onTap: () => onSeleccionar(1),
              ),

              _ItemBarra(
                etiqueta: 'Actividad',
                seleccionado: indiceActual == 2,
                icono: Icon(
                  indiceActual == 2
                      ? Icons.calendar_today_rounded
                      : Icons.calendar_today_outlined,
                  size: 24,
                  color: indiceActual == 2 ? _colorActivo : _colorInactivo,
                ),
                onTap: () => onSeleccionar(2),
              ),

              _ItemBarra(
                etiqueta: 'Perfil',
                seleccionado: indiceActual == 3,
                icono: estaLogueado
                    ? Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 142, 69, 184),
                          shape: BoxShape.circle,
                          border: indiceActual == 3
                              ? Border.all(color: _colorActivo, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          inicialUsuario,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.person_outline_rounded,
                        size: 27,
                        color: indiceActual == 3
                            ? _colorActivo
                            : _colorInactivo,
                      ),
                onTap: () => onSeleccionar(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campana de la barra superior con el globo de avisos no leídos.
class _CampanaAvisos extends StatelessWidget {
  const _CampanaAvisos({required this.push});

  final ServicioPush push;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: push.noLeidas,
      builder: (context, cantidad, _) {
        final texto = cantidad > 99 ? '99+' : '$cantidad';
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_outlined),
            if (cantidad > 0)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    texto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ItemBarra extends StatelessWidget {
  const _ItemBarra({
    required this.etiqueta,
    required this.seleccionado,
    required this.icono,
    required this.onTap,
  });

  final String etiqueta;
  final bool seleccionado;
  final Widget icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorTexto = seleccionado
        ? const Color(0xFF7C3AED)
        : const Color(0xFF111827);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 24, child: Center(child: icono)),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w500,
                color: colorTexto,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
