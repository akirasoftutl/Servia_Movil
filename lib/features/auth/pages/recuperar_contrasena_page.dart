import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
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
InputDecoration _decoracionCampo({required String hintText}) {
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
        fontSize: 15,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Botón superior derecho 'X' pegado arriba
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: _enviando
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
                    const SizedBox(height: 12),

                    const Text(
                      'Recupera tu\ncontraseña',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        height: 1.15,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 30),

                    const Text(
                      'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una contraseña nueva.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),

                    if (_enviado) ...[
                      const SizedBox(height: Espacios.l),
                      const Aviso(
                        tipo: TipoAviso.informacion,
                        icono: Icons.mark_email_read_outlined,
                        texto: MensajesAuth.correoRestablecimientoEnviado,
                      ),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: Espacios.l),
                      Aviso(texto: _error!),
                    ],

                    const SizedBox(height: 28),

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
                      enabled: !_enviando,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      validator: ValidacionesCliente.correo,
                      onFieldSubmitted: (_) => _enviar(),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                      decoration: _decoracionCampo(
                        hintText: 'Dirección de correo electrónico',
                      ),
                    ),

                    const SizedBox(height: 28),

                
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _enviando ? null : _enviar,
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
                        child: _enviando
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Enviar enlace'),
                      ),
                    ),

                    const SizedBox(height: 16),
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