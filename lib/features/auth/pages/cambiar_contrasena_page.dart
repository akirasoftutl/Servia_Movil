import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../data/auth_service.dart';
import '../mensajes.dart';

class CambiarContrasenaPage extends StatefulWidget {
  const CambiarContrasenaPage({super.key, this.authService});

  final AuthService? authService;

  @override
  State<CambiarContrasenaPage> createState() => _CambiarContrasenaPageState();
}

class _CambiarContrasenaPageState extends State<CambiarContrasenaPage> {
  final _formKey = GlobalKey<FormState>();
  late final AuthService _authService;
  final _actualController = TextEditingController();
  final _nuevaController = TextEditingController();
  final _confirmacionController = TextEditingController();

  bool _guardando = false;
  bool _ocultarActual = true;
  bool _ocultarNueva = true;
  bool _ocultarConfirmacion = true;
  String? _error;

  static const _tituloColor = Color(0xFF111318);
  static const _subtituloColor = Color(0xFF6E717A);
  static const _hintColor = Color(0xFFA0A3AB);
  static const _bordeColor = Color(0xFFD6D8DE);
  static const _bordeActivoColor = Color(0xFF141414);
  static const _errorColor = Color(0xFFD32F2F);
  static const _botonFondo = Color(0xFF141414);

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmacionController.dispose();
    super.dispose();
  }

  String? _validarActual(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña actual es obligatoria.';
    }
    return null;
  }

  String? _validarNueva(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria.';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres.';
    }
    return null;
  }

  String? _validarConfirmacion(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirma tu contraseña.';
    }
    if (value != _nuevaController.text) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  Future<void> _cambiar() async {
    if (_guardando) return;

    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      await _authService.cambiarContrasena(
        contrasenaActual: _actualController.text,
        contrasenaNueva: _nuevaController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(MensajesAuth.contrasenaActualizada)),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = MensajesAuth.mensajeDeCambioContrasena(error);
      });
    }
  }

  OutlineInputBorder _borde(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  Widget _campoContrasena({
    required TextEditingController controller,
    required String etiqueta,
    required String hint,
    required bool oculta,
    required VoidCallback alternarVisibilidad,
    required String? Function(String?) validator,
    TextInputAction textInputAction = TextInputAction.next,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        etiqueta,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _tituloColor,
          height: 1.25,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        enabled: !_guardando,
        obscureText: oculta,
        textInputAction: textInputAction,
        validator: validator,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: _tituloColor,
        ),
        onFieldSubmitted: textInputAction == TextInputAction.done
            ? (_) => _cambiar()
            : null,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: _hintColor,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: _borde(_bordeColor),
          enabledBorder: _borde(_bordeColor),
          disabledBorder: _borde(_bordeColor.withValues(alpha: 0.6)),
          focusedBorder: _borde(_bordeActivoColor, width: 1.5),
          errorBorder: _borde(_errorColor),
          focusedErrorBorder: _borde(_errorColor, width: 1.5),
          errorStyle: const TextStyle(
            fontSize: 13,
            color: _errorColor,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              onPressed: _guardando ? null : alternarVisibilidad,
              icon: Icon(
                oculta
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _subtituloColor,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              24,
              20,
              24,
              Espacios.xxl,
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _guardando ? null : () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: _tituloColor,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Cambiar contraseña',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: _tituloColor,
                  letterSpacing: -0.6,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Actualiza la contraseña de tu cuenta.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: _subtituloColor,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Aviso(texto: _error!),
                const SizedBox(height: Espacios.l),
              ],
              _campoContrasena(
                controller: _actualController,
                etiqueta: 'Contraseña actual',
                hint: 'Tu contraseña actual',
                oculta: _ocultarActual,
                alternarVisibilidad: () =>
                    setState(() => _ocultarActual = !_ocultarActual),
                validator: _validarActual,
              ),
              const SizedBox(height: 20),
              _campoContrasena(
                controller: _nuevaController,
                etiqueta: 'Contraseña nueva',
                hint: 'Mínimo 8 caracteres',
                oculta: _ocultarNueva,
                alternarVisibilidad: () =>
                    setState(() => _ocultarNueva = !_ocultarNueva),
                validator: _validarNueva,
              ),
              const SizedBox(height: 20),
              _campoContrasena(
                controller: _confirmacionController,
                etiqueta: 'Confirmar contraseña nueva',
                hint: 'Repite la contraseña nueva',
                oculta: _ocultarConfirmacion,
                alternarVisibilidad: () => setState(
                  () => _ocultarConfirmacion = !_ocultarConfirmacion,
                ),
                validator: _validarConfirmacion,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _guardando ? null : _cambiar,
                  style: FilledButton.styleFrom(
                    backgroundColor: _botonFondo,
                    disabledBackgroundColor: _botonFondo.withValues(alpha: 0.45),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _guardando
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Cambiar contraseña'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}