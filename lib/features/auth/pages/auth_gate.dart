import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../../../core/widgets/marca_servia.dart';
import '../../home/pages/home_page.dart';
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
  });

  final AuthService? authService;
  final PerfilService? perfilService;
  final RegistroClienteService? registroClienteService;
  final PerfilClienteService? perfilClienteService;
  final ReservasService? reservasService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;
  late final PerfilService _perfilService;

  StreamSubscription<User?>? _suscripcion;
  _EstadoSesion _estado = _EstadoSesion.verificando;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _perfilService = widget.perfilService ?? PerfilService();
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
      });
      return;
    }

    if (!mounted) return;
    setState(() => _estado = _EstadoSesion.verificando);

    try {
      final token = await usuario.getIdToken();
      final perfil = await _perfilService.obtenerYo(token!);

      if (!mounted) return;

      if (!perfil.esCliente) {
        setState(() => _mensaje = MensajesAuth.soloClientes);
        await _authService.cerrarSesion();
        if (!mounted) return;
        setState(() {
          _estado = _EstadoSesion.sinSesion;
        });
        return;
      }

      setState(() {
        _mensaje = null;
        _estado = _EstadoSesion.conSesion;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 403) {
        setState(() => _mensaje = MensajesAuth.cuentaDesactivada);
        await _authService.cerrarSesion();
        if (!mounted) return;
        setState(() {
          _estado = _EstadoSesion.sinSesion;
        });
        return;
      }
      // 401 u otro: el token ya no sirve, se cierra la sesión.
      setState(() => _mensaje = MensajesAuth.errorSesion);
      await _authService.cerrarSesion();
      if (!mounted) return;
      setState(() {
        _estado = _EstadoSesion.sinSesion;
      });
    } catch (_) {
      // Error de red: no se cierra la sesión, solo se ofrece reintentar.
      if (!mounted) return;
      setState(() {
        _estado = _EstadoSesion.errorRed;
      });
    }
  }

  void _reintentar() {
    final usuario = _authService.usuarioActual;
    if (usuario != null) {
      _alCambiarSesion(usuario);
    } else {
      setState(() => _estado = _EstadoSesion.sinSesion);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_estado) {
      case _EstadoSesion.verificando:
        return const _PantallaCarga();
      case _EstadoSesion.sinSesion:
        return LoginPage(
          mensajeInicial: _mensaje,
          authService: _authService,
          registroClienteService: widget.registroClienteService,
        );
      case _EstadoSesion.conSesion:
        return HomePage(
          onCerrarSesion: _cerrarSesion,
          authService: _authService,
          perfilClienteService: widget.perfilClienteService,
          reservasService: widget.reservasService,
        );
      case _EstadoSesion.errorRed:
        return _PantallaErrorRed(onReintentar: _reintentar);
    }
  }

  Future<void> _cerrarSesion() {
    return _authService.cerrarSesion();
  }
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
