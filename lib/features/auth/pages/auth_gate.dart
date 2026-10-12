import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../home/pages/home_page.dart';
import '../data/auth_service.dart';
import '../data/perfil.dart';
import '../data/perfil_service.dart';
import '../mensajes.dart';
import 'login_page.dart';

enum _EstadoSesion { verificando, sinSesion, conSesion, errorRed }

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.authService, this.perfilService});

  final AuthService? authService;
  final PerfilService? perfilService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _authService;
  late final PerfilService _perfilService;

  StreamSubscription<User?>? _suscripcion;
  _EstadoSesion _estado = _EstadoSesion.verificando;
  Perfil? _perfil;
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
        _perfil = null;
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
        setState(
          () => _mensaje = MensajesAuth.soloClientes,
        );
        await _authService.cerrarSesion();
        if (!mounted) return;
        setState(() {
          _estado = _EstadoSesion.sinSesion;
          _perfil = null;
        });
        return;
      }

      setState(() {
        _mensaje = null;
        _perfil = perfil;
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
          _perfil = null;
        });
        return;
      }
      // 401 u otro: el token ya no sirve, se cierra la sesión.
      setState(() => _mensaje = MensajesAuth.errorSesion);
      await _authService.cerrarSesion();
      if (!mounted) return;
      setState(() {
        _estado = _EstadoSesion.sinSesion;
        _perfil = null;
      });
    } catch (_) {
      // Error de red: no se cierra la sesión, solo se ofrece reintentar.
      if (!mounted) return;
      setState(() {
        _estado = _EstadoSesion.errorRed;
        _perfil = null;
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
        return LoginPage(mensajeInicial: _mensaje, authService: _authService);
      case _EstadoSesion.conSesion:
        return HomePage(
          perfil: _perfil!,
          onCerrarSesion: _cerrarSesion,
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

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 64, color: Color(0xFF7B1FA2)),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _PantallaErrorRed extends StatelessWidget {
  const _PantallaErrorRed({required this.onReintentar});

  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 64,
                color: Colors.black38,
              ),
              const SizedBox(height: 16),
              const Text(
                MensajesAuth.errorRed,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
                  shape: const StadiumBorder(),
                ),
                onPressed: onReintentar,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}