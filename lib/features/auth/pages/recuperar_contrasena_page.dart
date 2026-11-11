import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/marca_servia.dart';
import '../data/auth_service.dart';
import '../mensajes.dart';
import '../validaciones.dart';

/// Recuperación de contraseña desde el inicio de sesión. Firebase envía el
/// enlace al correo; la app no consulta si la cuenta existe ni usa la API.
class RecuperarContrasenaPage extends StatefulWidget {
  const RecuperarContrasenaPage({
    super.key,
    this.authService,
    this.correoInicial,
  });

  final AuthService? authService;
  final String? correoInicial;

  @override
  State<RecuperarContrasenaPage> createState() =>
      _RecuperarContrasenaPageState();
}

class _RecuperarContrasenaPageState extends State<RecuperarContrasenaPage> {
  final _formKey = GlobalKey<FormState>();
  late final AuthService _authService;
  late final TextEditingController _correoController;

  bool _enviando = false;
  bool _enviado = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _correoController = TextEditingController(text: widget.correoInicial ?? '');
  }

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;

    setState(() {
      _error = null;
      _enviado = false;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enviando = true);
    try {
      await _authService.enviarCorreoRestablecimiento(
        _correoController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _enviado = true;
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      // Mismo mensaje exista o no la cuenta: nunca se revela user-not-found.
      if (error.code == 'user-not-found') {
        setState(() {
          _enviando = false;
          _enviado = true;
        });
        return;
      }
      setState(() {
        _enviando = false;
        _error = MensajesAuth.mensajeDeRecuperacion(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _error = MensajesAuth.errorRed;
      });
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
                      'Recupera tu contraseña',
                      textAlign: TextAlign.center,
                      style: textos.headlineMedium,
                    ),
                    const SizedBox(height: Espacios.xs),
                    Text(
                      'Escribe el correo de tu cuenta y te enviaremos un enlace '
                      'para crear una contraseña nueva.',
                      textAlign: TextAlign.center,
                      style: textos.bodyLarge?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Espacios.xl),
                    if (_enviado) ...[
                      const Aviso(
                        tipo: TipoAviso.informacion,
                        icono: Icons.mark_email_read_outlined,
                        texto: MensajesAuth.correoRestablecimientoEnviado,
                      ),
                      const SizedBox(height: Espacios.l),
                    ],
                    if (_error != null) ...[
                      Aviso(texto: _error!),
                      const SizedBox(height: Espacios.l),
                    ],
                    const EtiquetaCampo('Correo electrónico'),
                    TextFormField(
                      controller: _correoController,
                      enabled: !_enviando,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      validator: ValidacionesCliente.correo,
                      onFieldSubmitted: (_) => _enviar(),
                      decoration: const InputDecoration(
                        hintText: 'Dirección de correo electrónico',
                      ),
                    ),
                    const SizedBox(height: Espacios.xl),
                    ElevatedButton(
                      onPressed: _enviando ? null : _enviar,
                      child: _enviando
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Enviar enlace'),
                    ),
                    const SizedBox(height: Espacios.s),
                    TextButton(
                      onPressed: _enviando
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Volver a iniciar sesión'),
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
