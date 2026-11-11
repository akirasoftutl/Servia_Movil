import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/marca_servia.dart';
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: LogoServia(tamano: 60, enMosaico: true),
                    ),
                    const SizedBox(height: Espacios.l),
                    Text(
                      'Crea una cuenta',
                      textAlign: TextAlign.center,
                      style: textos.headlineMedium,
                    ),
                    const SizedBox(height: Espacios.xs),
                    Text(
                      'Regístrate para comenzar',
                      textAlign: TextAlign.center,
                      style: textos.bodyLarge?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Espacios.xl),
                    if (_errorGeneral != null) ...[
                      Aviso(texto: _errorGeneral!),
                      const SizedBox(height: Espacios.l),
                    ],
                    const EtiquetaCampo('Nombre completo'),
                    TextFormField(
                      controller: _nombreController,
                      textCapitalization: TextCapitalization.words,
                      validator: ValidacionesCliente.nombre,
                      decoration: const InputDecoration(
                        hintText: 'Tu nombre y apellido',
                      ),
                    ),
                    const SizedBox(height: Espacios.l),
                    const EtiquetaCampo('Teléfono'),
                    TextFormField(
                      controller: _telefonoController,
                      keyboardType: TextInputType.phone,
                      validator: ValidacionesCliente.telefono,
                      decoration: const InputDecoration(
                        hintText: 'Teléfono (10 dígitos)',
                      ),
                    ),
                    const SizedBox(height: Espacios.l),
                    const EtiquetaCampo('Correo electrónico'),
                    TextFormField(
                      controller: _correoController,
                      keyboardType: TextInputType.emailAddress,
                      validator: ValidacionesCliente.correo,
                      decoration: const InputDecoration(
                        hintText: 'Dirección de correo electrónico',
                      ),
                    ),
                    const SizedBox(height: Espacios.l),
                    const EtiquetaCampo('Contraseña'),
                    TextFormField(
                      controller: _contrasenaController,
                      obscureText: _ocultarContrasena,
                      validator: _validarContrasena,
                      decoration: InputDecoration(
                        hintText: 'Crea una contraseña',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _ocultarContrasena
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => _ocultarContrasena = !_ocultarContrasena,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: Espacios.xl),
                    ElevatedButton(
                      onPressed: _cargando ? null : _registrar,
                      child: _cargando
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Crear cuenta'),
                    ),
                    const SizedBox(height: Espacios.s),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '¿Ya tienes cuenta?',
                          style: textos.bodyMedium?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: _cargando
                              ? null
                              : () {
                                  Navigator.pop(context);
                                },
                          child: const Text('Inicia sesión'),
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
