import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/marca_servia.dart';
import '../../home/pages/home_page.dart';
import '../../notificaciones/data/notificaciones_service.dart';
import '../../notificaciones/data/servicio_push.dart';
import '../../reservas/data/reservas_service.dart';
import '../data/auth_service.dart';
import '../data/perfil_service.dart';
import '../../perfil/data/perfil_cliente_service.dart';
import '../data/registro_cliente_service.dart';
import '../mensajes.dart';
import 'login_page.dart';

enum _EstadoSesion { verificando, sinSesion, conSesion, errorRed }

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.authService,
    this.perfilService,
    this.registroClienteService,
    this.perfilClienteService,
    this.reservasService,
    this.notificacionesService,
    this.push,
  });

  final AuthService? authService;
  final PerfilService? perfilService;
  final RegistroClienteService? registroClienteService;
  final PerfilClienteService? perfilClienteService;
  final ReservasService? reservasService;
  final NotificacionesService? notificacionesService;
  final ServicioPush? push;

  @override
  State<AuthGate> createState() => _AuthGateState();
}


class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;
  late final PerfilService _perfilService;
  late final ServicioPush _push;

  StreamSubscription<User?>? _suscripcion;

  _EstadoSesion _estado = _EstadoSesion.verificando;
  String? _mensaje;

  bool _mostrarLogin = false;

  @override
  void initState() {
    super.initState();

    _push = widget.push ?? ServicioPush();
    _authService = widget.authService ?? AuthService(push: _push);
    _perfilService = widget.perfilService ?? PerfilService();

    // Los listeners viven mientras la app esté abierta; `getInitialMessage`
    // se guarda hasta que sepamos que hay una sesión de cliente.
    _push.configurar();
    unawaited(_push.cargarMensajeInicial());

    // Sin sesión mostramos de inmediato el inicio con su barra inferior, sin
    // esperar a que el stream de Firebase emita el estado inicial.
    if (_authService.usuarioActual == null) {
      _estado = _EstadoSesion.sinSesion;
    }

    _suscripcion = _authService.cambiosDeSesion.listen(_alCambiarSesion);
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  Future<void> _alCambiarSesion(User? usuario) async {
    if (usuario == null) {
      if (!mounted) return;

      setState(() {
        _estado = _EstadoSesion.sinSesion;
        _mostrarLogin = false;
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      _estado = _EstadoSesion.verificando;
    });

    try {
      final token = await usuario.getIdToken();
      final perfil = await _perfilService.obtenerYo(token!);

      if (!mounted) return;

      if (!perfil.esCliente) {
        setState(() {
          _mensaje = MensajesAuth.soloClientes;
        });

        await _cerrarSesion();

        if (!mounted) return;

        setState(() {
          _estado = _EstadoSesion.sinSesion;
          _mostrarLogin = false;
        });

        return;
      }

      setState(() {
        _mensaje = null;
        _estado = _EstadoSesion.conSesion;
        _mostrarLogin = false;
      });

      // Permiso y token FCM solo después de confirmar que es cliente.
      unawaited(_registrarPush(token));
    } on ApiException catch (error) {
      if (!mounted) return;

      if (error.statusCode == 403) {
        setState(() {
          _mensaje = MensajesAuth.cuentaDesactivada;
        });

        await _cerrarSesion();

        if (!mounted) return;

        setState(() {
          _estado = _EstadoSesion.sinSesion;
          _mostrarLogin = false;
        });

        return;
      }

 
      setState(() {
        _mensaje = MensajesAuth.errorSesion;
      });

      await _cerrarSesion();

      if (!mounted) return;

      setState(() {
        _estado = _EstadoSesion.sinSesion;
        _mostrarLogin = false;
      });
    } catch (_) {
      // Error de red: no se cierra la sesión.
      if (!mounted) return;

      setState(() {
        _estado = _EstadoSesion.errorRed;
      });
    }
  }

  // Abrir Login desde el apartado Perfil.
  void _abrirLogin() {
    setState(() {
      _mostrarLogin = true;
    });
  }

  // Regresar al Home desde Login.
  void _regresarHome() {
    setState(() {
      _mostrarLogin = false;
      _mensaje = null;
    });
  }

  void _reintentar() {
    final usuario = _authService.usuarioActual;

    if (usuario != null) {
      _alCambiarSesion(usuario);
    } else {
      setState(() {
        _estado = _EstadoSesion.sinSesion;
        _mostrarLogin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_estado) {
      case _EstadoSesion.verificando:
        return const _PantallaCarga();

      case _EstadoSesion.sinSesion:
        if (_mostrarLogin) {
          return WillPopScope(
            onWillPop: () async {
              _regresarHome();
              return false;
            },
            child: LoginPage(
              mensajeInicial: _mensaje,
              authService: _authService,
              registroClienteService: widget.registroClienteService,
              onRegresar: _regresarHome,
            ),
          );
        }

        return HomePage(
          // Key distinta por estado: al cerrar sesión se reinicia en Inicio
          // (índice 0) en vez de conservar Perfil/Actividad sin contenido.
          key: const ValueKey('home-sin-sesion'),
          onCerrarSesion: _cerrarSesion,
          onSolicitarLogin: _abrirLogin,
          authService: _authService,
          perfilClienteService: widget.perfilClienteService,
          reservasService: widget.reservasService,
          notificacionesService: widget.notificacionesService,
          push: _push,
        );

      case _EstadoSesion.conSesion:
        return HomePage(
          key: const ValueKey('home-con-sesion'),
          onCerrarSesion: _cerrarSesion,
          onSolicitarLogin: _abrirLogin,
          authService: _authService,
          perfilClienteService: widget.perfilClienteService,
          reservasService: widget.reservasService,
          notificacionesService: widget.notificacionesService,
          push: _push,
        );

      case _EstadoSesion.errorRed:
        return _PantallaErrorRed(
          onReintentar: _reintentar,
        );
    }
  }

  Future<void> _registrarPush(String token) async {
    try {
      await _push.registrar(token);
      await _push.procesarMensajePendiente(token);
    } catch (_) {
      // Los avisos de la lista no dependen del permiso de notificaciones.
    }
  }

  /// [AuthService.cerrarSesion] da de baja el token FCM antes de cerrar
  /// Firebase, tanto aquí como desde la fila «Cerrar sesión» de Mi perfil.
  Future<void> _cerrarSesion() => _authService.cerrarSesion();
}


class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  // Continúa la pantalla de arranque nativa: mismo logo, mismo fondo blanco.
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    body: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LogoServia(tamano: 96),
          SizedBox(height: Espacios.xl),
          EstadoCargando(compacto: true),
        ],
      ),
    ),
  );
}

class _PantallaErrorRed extends StatelessWidget {
  const _PantallaErrorRed({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: EstadoError(
        mensaje: MensajesAuth.errorRed,
        onReintentar: onReintentar,
      ),
    ),
  );
}
