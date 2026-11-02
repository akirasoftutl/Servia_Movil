import 'package:flutter/material.dart';

import '../../negocios/data/negocios_service.dart';
import '../../negocios/mensajes.dart';
import '../../negocios/pages/lista_negocios_page.dart';
import '../../../core/network/api_exception.dart';
import '../../reservas/mensajes.dart';
import '../data/auth_service.dart';
import '../data/perfil_service.dart';
import '../data/registro_cliente_service.dart';
import '../mensajes.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.mensajeInicial,
    this.authService,
    this.registroClienteService,
    this.negociosService,
    this.regresarAlIniciar = false,
    this.perfilService,
  });

  /// Mensaje que llega desde AuthGate (p. ej. cuenta de negocio o desactivada).
  final String? mensajeInicial;
  final AuthService? authService;
  final RegistroClienteService? registroClienteService;
  final NegociosService? negociosService;

  /// Se abrió desde una reserva sin sesión: al iniciar sesión (o registrarse)
  /// como cliente se cierra con `true` para regresar al punto de la reserva.
  final bool regresarAlIniciar;
  final PerfilService? perfilService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final AuthService _authService;
  late final PerfilService _perfilService;
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();

  bool _cargando = false;
  bool _ocultarContrasena = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _perfilService = widget.perfilService ?? PerfilService();
  }

  @override
  void dispose() {
    _correoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (_cargando) return;

    final correo = _correoController.text.trim();
    final contrasena = _contrasenaController.text;

    if (correo.isEmpty || contrasena.isEmpty) {
      setState(() => _error = MensajesAuth.camposVacios);
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await _authService.iniciarSesion(correo: correo, contrasena: contrasena);
      if (!mounted) return;
      if (widget.regresarAlIniciar) {
        await _regresarALaReserva();
        return;
      }
      setState(() => _cargando = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = MensajesAuth.mensajeDeInicioSesion(error);
      });
    }
  }

  /// Solo cuentas de cliente activas regresan a la reserva (RN-09); las demás
  /// se salen igual que en AuthGate.
  Future<void> _regresarALaReserva() async {
    setState(() => _cargando = true);
    String? rechazo;
    try {
      final token = await _authService.usuarioActual?.getIdToken();
      if (token == null) throw const ApiException(401, 'Sin sesión.');
      final perfil = await _perfilService.obtenerYo(token);
      if (!mounted) return;
      if (perfil.esCliente) {
        setState(() => _cargando = false);
        Navigator.pop(context, true);
        return;
      }
      rechazo = MensajesAuth.soloClientes;
    } on ApiException catch (error) {
      rechazo = error.statusCode == 403
          ? MensajesAuth.cuentaDesactivada
          : MensajesAuth.errorSesion;
    } catch (_) {
      // Error de red: la sesión sigue abierta; basta volver a intentarlo.
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = MensajesAuth.errorRed;
      });
      return;
    }
    await _authService.cerrarSesion();
    if (!mounted) return;
    setState(() {
      _cargando = false;
      _error = rechazo;
    });
  }

  Future<void> _abrirRegistro() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterPage(
          authService: _authService,
          registroClienteService: widget.registroClienteService,
        ),
      ),
    );
    if (!mounted || !widget.regresarAlIniciar) return;
    if (_authService.usuarioActual != null) await _regresarALaReserva();
  }

  String? get _mensajeVisible {
    if (widget.mensajeInicial != null && widget.mensajeInicial!.isNotEmpty) {
      return widget.mensajeInicial;
    }
    return _error;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF512DA8),
                  Color(0xFF7B1FA2),
                  Color(0xFFC2185B),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  left: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: -40,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.80,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Column(
                        children: [
                          Text(
                            'Bienvenido a Servia',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Inicia sesión con tu cuenta de cliente',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.regresarAlIniciar) ...[
                      Text(
                        MensajesReservas.iniciarSesionParaReservar,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed:
                            _cargando ? null : () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                    ] else
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
                        builder: (_) => ListaNegociosPage(negociosService: widget.negociosService),
                      )),
                      child: const Text(MensajesNegocios.verSinSesion),
                    ),
                    const SizedBox(height: 24),
                    if (_mensajeVisible != null) ...[
                      _MensajeError(texto: _mensajeVisible!),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Correo electrónico',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _correoController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Dirección de correo electrónico',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFB39DDB),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Contraseña',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contrasenaController,
                      obscureText: _ocultarContrasena,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _iniciarSesion(),
                      decoration: InputDecoration(
                        hintText: 'Tu contraseña',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _ocultarContrasena = !_ocultarContrasena,
                          ),
                          icon: Icon(
                            _ocultarContrasena
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFB39DDB),
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "¿No tienes cuenta?",
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        TextButton(
                          onPressed: _cargando ? null : _abrirRegistro,
                          child: const Text(
                            "Regístrate",
                            style: TextStyle(
                              color: Color(0xFF7B1FA2),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B1FA2),
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        onPressed: _cargando ? null : _iniciarSesion,
                        child: _cargando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MensajeError extends StatelessWidget {
  const _MensajeError({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFC62828),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}