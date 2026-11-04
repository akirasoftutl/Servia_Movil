import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/marca_servia.dart';
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
    final tema = Theme.of(context);
    final textos = tema.textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Espacios.xl,
              vertical: Espacios.l,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: LogoServia(tamano: 72, enMosaico: true)),
                  const SizedBox(height: Espacios.l),
                  Text(
                    'Bienvenido a Servia',
                    textAlign: TextAlign.center,
                    style: textos.headlineMedium,
                  ),
                  const SizedBox(height: Espacios.xs),
                  Text(
                    'Inicia sesión con tu cuenta de cliente',
                    textAlign: TextAlign.center,
                    style: textos.bodyLarge?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.regresarAlIniciar) ...[
                    const SizedBox(height: Espacios.l),
                    const Aviso(
                      tipo: TipoAviso.informacion,
                      icono: Icons.event_available_outlined,
                      texto: MensajesReservas.iniciarSesionParaReservar,
                    ),
                  ],
                  const SizedBox(height: Espacios.xl),
                  if (_mensajeVisible != null) ...[
                    Aviso(texto: _mensajeVisible!),
                    const SizedBox(height: Espacios.l),
                  ],
                  const EtiquetaCampo('Correo electrónico'),
                  TextField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Dirección de correo electrónico',
                    ),
                  ),
                  const SizedBox(height: Espacios.l),
                  const EtiquetaCampo('Contraseña'),
                  TextField(
                    controller: _contrasenaController,
                    obscureText: _ocultarContrasena,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _iniciarSesion(),
                    decoration: InputDecoration(
                      hintText: 'Tu contraseña',
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _ocultarContrasena = !_ocultarContrasena,
                        ),
                        icon: Icon(
                          _ocultarContrasena
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Espacios.xl),
                  ElevatedButton(
                    onPressed: _cargando ? null : _iniciarSesion,
                    child: _cargando
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: Espacios.s),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '¿No tienes cuenta?',
                        style: textos.bodyMedium?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: _cargando ? null : _abrirRegistro,
                        child: const Text('Regístrate'),
                      ),
                    ],
                  ),
                  if (widget.regresarAlIniciar)
                    TextButton(
                      onPressed: _cargando
                          ? null
                          : () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    )
                  else ...[
                    const SizedBox(height: Espacios.s),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ListaNegociosPage(
                            negociosService: widget.negociosService,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text(MensajesNegocios.verSinSesion),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
