import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../data/auth_service.dart';
import '../data/registro_cliente_service.dart';
import '../mensajes.dart';
import '../validaciones.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    this.registroClienteService,
    this.authService,
  });

  final RegistroClienteService? registroClienteService;
  final AuthService? authService;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  late final RegistroClienteService _registroService;
  late final AuthService _authService;

  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _contrasenaController = TextEditingController();

  bool _cargando = false;
  bool _ocultarContrasena = true;
  String? _errorGeneral;

  @override
  void initState() {
    super.initState();
    _registroService =
        widget.registroClienteService ?? RegistroClienteService();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  String? _validarContrasena(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria.';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    return null;
  }

  Future<void> _registrar() async {
    if (_cargando) return;

    setState(() => _errorGeneral = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _cargando = true);

    try {
      await _registroService.registrarCliente(
        RegistroClienteRequest(
          nombre: _nombreController.text.trim(),
          correo: _correoController.text.trim(),
          telefono: _telefonoController.text.trim(),
          contrasena: _contrasenaController.text,
        ),
      );

      // Iniciar sesión después de crear la cuenta
      await _authService.iniciarSesion(
        correo: _correoController.text.trim(),
        contrasena: _contrasenaController.text,
      );

      if (!mounted) return;
      setState(() => _cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu cuenta se creó correctamente')),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _cargando = false);

      setState(() => _errorGeneral = MensajesAuth.mensajeDeRegistro(error));
    }
  }

  InputDecoration _decoracionCampo({
    required String hintText,
    Widget? suffixIcon,
  }) {
    const bordeBase = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFD1D5DB), width: 1.2),
    );

    const bordeError = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFDC2626), width: 1.2),
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
      errorBorder: bordeError,
      focusedErrorBorder: bordeError,
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Botón superior derecho 'X' para regresar al login
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _cargando
                            ? null
                            : () => Navigator.pop(context),
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
                      'Crea una cuenta',
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
                      'Regístrate para comenzar.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),

                    if (_errorGeneral != null) ...[
                      const SizedBox(height: Espacios.l),
                      Aviso(texto: _errorGeneral!),
                    ],

                    const SizedBox(height: 28),

                    // Campo: Nombre completo
                    const Text(
                      'Nombre completo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nombreController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: ValidacionesCliente.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                      decoration: _decoracionCampo(
                        hintText: 'Tu nombre y apellido',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Campo: Teléfono
                    const Text(
                      'Teléfono',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _telefonoController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: ValidacionesCliente.telefono,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                      decoration: _decoracionCampo(
                        hintText: 'Teléfono (10 dígitos)',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Campo: Correo electrónico
                    const Text(
                      'Correo electrónico',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _correoController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      validator: ValidacionesCliente.correo,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                      decoration: _decoracionCampo(
                        hintText: 'Dirección de correo electrónico',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Campo: Contraseña
                    const Text(
                      'Contraseña',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contrasenaController,
                      obscureText: _ocultarContrasena,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _registrar(),
                      validator: _validarContrasena,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                      decoration: _decoracionCampo(
                        hintText: 'Crea una contraseña',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _ocultarContrasena
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF6B7280),
                          ),
                          onPressed: () {
                            setState(
                              () => _ocultarContrasena = !_ocultarContrasena,
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Botón principal estilo píldora negra
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _registrar,
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
                            : const Text('Crear cuenta'),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Enlace discreto para volver al inicio de sesión
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Ya tienes cuenta?',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        TextButton(
                          onPressed: _cargando
                              ? null
                              : () {
                                  Navigator.pop(context);
                                },
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFE05A97), Color(0xFF9D4EDD)],
                            ).createShader(bounds),
                            child: const Text(
                              'Inicia sesión',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
      ),
    );
  }
}
