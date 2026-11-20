import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../negocios/data/negocios_service.dart';
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
    this.onRegresar,
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

  /// Cierra el login volviendo a la pantalla que lo abrió. Lo usa AuthGate
  /// cuando el login se muestra en la raíz (pestaña Perfil sin sesión), donde
  /// hacer pop saldría de la app en vez de volver al inicio con su barra.
  final VoidCallback? onRegresar;

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

  Future<void> _iniciarSesionConGoogle() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // TODO: Conecta aquí tu método de AuthService, por ejemplo:
      // await _authService.iniciarSesionConGoogle();
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

  InputDecoration _decoracionCampo({
    required String hintText,
    Widget? suffixIcon,
  }) {
    const bordeBase = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: bordeBase,
      enabledBorder: bordeBase,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF111827), width: 1.5),
      ),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Botón superior derecho 'X'
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: _cargando
                          ? null
                          : () {
                              if (widget.onRegresar != null) {
                                widget.onRegresar!.call();
                              } else if (widget.regresarAlIniciar) {
                                Navigator.pop(context, false);
                              } else {
                                Navigator.pop(context);
                              }
                            },
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF111827),
                        size: 26,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Título principal alineado a la izquierda
                  const Text(
                    'Iniciar sesión o\nregistrarse',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtítulo
                  const Text(
                    'Necesitaremos verificar que eres tú.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B7280),
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

                  if (_mensajeVisible != null) ...[
                    const SizedBox(height: Espacios.l),
                    Aviso(texto: _mensajeVisible!),
                  ],

                  const SizedBox(height: 28),

                  // Etiqueta + Campo Correo electrónico
                  const Text(
                    'Correo electrónico',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF111827),
                    ),
                    decoration: _decoracionCampo(
                      hintText: 'Dirección de correo electrónico',
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Contraseña',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _contrasenaController,
                    obscureText: _ocultarContrasena,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _iniciarSesion(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF111827),
                    ),
                    decoration: _decoracionCampo(
                      hintText: 'Tu contraseña',
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _ocultarContrasena = !_ocultarContrasena,
                        ),
                        icon: Icon(
                          _ocultarContrasena
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Botón principal estilo píldora negra
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _cargando ? null : _iniciarSesion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F0F0F),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF9CA3AF),
                        elevation: 0,
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: _cargando
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continuar'),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    children: [
                      const Expanded(
                        child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF6B7280),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _cargando ? null : _iniciarSesionConGoogle,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF111827),
                        side: const BorderSide(
                          color: Color(0xFFD1D5DB),
                          width: 1.2,
                        ),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: const Row(
                        children: [
                          _GoogleLogo(size: 22),
                          Expanded(
                            child: Text(
                              'Continuar con Google',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          // Espacio compensatorio para centrar el texto exactamente
                          SizedBox(width: 22),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿No tienes cuenta?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      TextButton(
                        onPressed: _cargando ? null : _abrirRegistro,
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFE05A97), 
                              Color(0xFF9D4EDD), 
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'Regístrate',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white, // Necesario para que el degradado se pinte encima
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.19;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Azul (arco derecho + barra horizontal)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.15, 1.05, false, paint);
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width - strokeWidth * 0.25, center.dy),
      paint..style = PaintingStyle.fill,
    );
    // Barra horizontal de la G
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - strokeWidth / 2,
        radius - strokeWidth * 0.1,
        strokeWidth,
      ),
      paint,
    );

    paint.style = PaintingStyle.stroke;

    // Verde (inferior)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.85, 1.75, false, paint);

    // Amarillo (izquierda)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.55, 1.15, false, paint);

    // Rojo (superior)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.65, 1.85, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
