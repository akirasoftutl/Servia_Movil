import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../data/auth_service.dart';
import '../mensajes.dart';

/// Cambio de contraseña con la sesión iniciada. Reautentica con la actual y
/// actualiza la nueva directamente en Firebase Authentication.
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
      EtiquetaCampo(etiqueta),
      TextFormField(
        controller: controller,
        enabled: !_guardando,
        obscureText: oculta,
        textInputAction: textInputAction,
        validator: validator,
        onFieldSubmitted: textInputAction == TextInputAction.done
            ? (_) => _cambiar()
            : null,
        decoration: InputDecoration(
          hintText: hint,
          suffixIcon: IconButton(
            onPressed: _guardando ? null : alternarVisibilidad,
            icon: Icon(
              oculta
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Espacios.l,
            Espacios.m,
            Espacios.l,
            Espacios.xxl,
          ),
          children: [
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
            const SizedBox(height: Espacios.l),
            _campoContrasena(
              controller: _nuevaController,
              etiqueta: 'Contraseña nueva',
              hint: 'Mínimo 8 caracteres',
              oculta: _ocultarNueva,
              alternarVisibilidad: () =>
                  setState(() => _ocultarNueva = !_ocultarNueva),
              validator: _validarNueva,
            ),
            const SizedBox(height: Espacios.l),
            _campoContrasena(
              controller: _confirmacionController,
              etiqueta: 'Confirmar contraseña nueva',
              hint: 'Repite la contraseña nueva',
              oculta: _ocultarConfirmacion,
              alternarVisibilidad: () =>
                  setState(() => _ocultarConfirmacion = !_ocultarConfirmacion),
              validator: _validarConfirmacion,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: Espacios.xl),
            FilledButton(
              onPressed: _guardando ? null : _cambiar,
              child: _guardando
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Cambiar contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}
