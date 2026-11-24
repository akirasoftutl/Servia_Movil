import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/etiqueta_estado.dart';
import '../../auth/mensajes.dart';
import '../../reservas/fechas_reserva.dart';
import '../../reservas/mensajes.dart';
import '../data/cuenta_con_reservas.dart';
import '../mensajes.dart';
import 'estilos_perfil.dart';

/// Cómo terminó el diálogo de eliminar la cuenta.
enum ResultadoEliminarCuenta { eliminada, verReservas, cancelada }

/// Confirmación de la baja de la cuenta (HU-C14): explica qué se elimina y qué
/// se conserva, pide la contraseña y llama a [eliminar] (reautenticar y
/// `DELETE /usuarios/yo`). Los errores se muestran aquí mismo, sin cerrar la
/// sesión; con reservas por atender (409) lista los folios y ofrece verlas.
class DialogoEliminarCuenta extends StatefulWidget {
  const DialogoEliminarCuenta({super.key, required this.eliminar});

  final Future<void> Function(String contrasena) eliminar;

  @override
  State<DialogoEliminarCuenta> createState() => _DialogoEliminarCuentaState();
}

class _DialogoEliminarCuentaState extends State<DialogoEliminarCuenta> {
  final _formKey = GlobalKey<FormState>();
  final _contrasena = TextEditingController();
  bool _oculta = true;
  bool _eliminando = false;
  String? _error;
  CuentaConReservasException? _conflicto;

  @override
  void dispose() {
    _contrasena.dispose();
    super.dispose();
  }

  static String _mensajeDe(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return MensajesAuth.contrasenaActualIncorrecta;
        case 'too-many-requests':
          return 'Demasiados intentos. Espera un momento y vuelve a intentar.';
        case 'requires-recent-login':
        case 'user-not-found':
        case 'user-disabled':
        case 'user-token-expired':
        case 'invalid-user-token':
          return MensajesAuth.errorSesion;
      }
      return MensajesAuth.errorRed;
    }
    if (error is ApiException) return error.mensaje;
    return MensajesAuth.errorRed;
  }

  Future<void> _confirmar() async {
    if (_eliminando) return;
    setState(() {
      _error = null;
      _conflicto = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _eliminando = true);
    try {
      await widget.eliminar(_contrasena.text);
      if (!mounted) return;
      Navigator.pop(context, ResultadoEliminarCuenta.eliminada);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _eliminando = false;
        if (error is CuentaConReservasException) {
          _conflicto = error;
        } else {
          _error = _mensajeDe(error);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflicto = _conflicto;
    return AlertDialog(
      title: const Text(MensajesPerfil.eliminarTitulo),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(MensajesPerfil.eliminarSeElimina),
              const SizedBox(height: Espacios.m),
              const Text(MensajesPerfil.eliminarSeConserva),
              const SizedBox(height: Espacios.m),
              const Text(MensajesPerfil.eliminarIrreversible),
              const SizedBox(height: Espacios.l),
              const EtiquetaCampo(MensajesPerfil.contrasenaActual),
              TextFormField(
                key: const Key('campo-contrasena-eliminar'),
                controller: _contrasena,
                enabled: !_eliminando,
                obscureText: _oculta,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _confirmar(),
                validator: (valor) => (valor == null || valor.isEmpty)
                    ? MensajesPerfil.eliminarContrasenaObligatoria
                    : null,
                decoration: InputDecoration(
                  hintText: MensajesPerfil.contrasenaActual,
                  suffixIcon: IconButton(
                    tooltip: _oculta
                        ? MensajesPerfil.mostrarContrasena
                        : MensajesPerfil.ocultarContrasena,
                    onPressed: () => setState(() => _oculta = !_oculta),
                    icon: Icon(
                      _oculta
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: Espacios.m),
                Aviso(texto: _error!),
              ],
              if (conflicto != null) ...[
                const SizedBox(height: Espacios.m),
                Aviso(texto: conflicto.mensaje),
                for (final reserva in conflicto.reservas)
                  _FilaReserva(reserva: reserva),
              ],
              if (_eliminando) ...[
                const SizedBox(height: Espacios.l),
                // `EstadoCargando` usa LayoutBuilder y no cabe en un
                // AlertDialog (calcula dimensiones intrínsecas).
                Semantics(
                  liveRegion: true,
                  child: const Row(
                    children: [
                      SizedBox.square(
                        dimension: Espacios.xl,
                        child: CircularProgressIndicator(),
                      ),
                      SizedBox(width: Espacios.m),
                      Expanded(child: Text(MensajesPerfil.eliminandoCuenta)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _eliminando
              ? null
              : () => Navigator.pop(context, ResultadoEliminarCuenta.cancelada),
          style: estiloPildoraSecundaria(context),
          child: const Text(MensajesPerfil.cancelar),
        ),
        // Siempre a la vista (las acciones no se desplazan con el texto).
        if (conflicto != null)
          OutlinedButton(
            onPressed: _eliminando
                ? null
                : () => Navigator.pop(
                    context,
                    ResultadoEliminarCuenta.verReservas,
                  ),
            style: estiloPildoraSecundaria(context),
            child: const Text(MensajesPerfil.verMisReservas),
          ),
        FilledButton(
          onPressed: _eliminando ? null : _confirmar,
          style: estiloPildoraPrincipal(context, destructiva: true),
          child: const Text(MensajesPerfil.eliminarConfirmar),
        ),
      ],
    );
  }
}

/// Una reserva por atender: folio, estado y fecha en la zona de México.
class _FilaReserva extends StatelessWidget {
  const _FilaReserva({required this.reserva});

  final ReservaPorAtender reserva;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final confirmada = reserva.estado == 'confirmada';
    return Padding(
      padding: const EdgeInsets.only(top: Espacios.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: Espacios.s,
            runSpacing: Espacios.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(reserva.folio, style: tema.textTheme.titleSmall),
              EtiquetaEstado(
                texto: confirmada
                    ? MensajesReservas.estadoConfirmada
                    : MensajesReservas.estadoPendiente,
                tono: confirmada ? TonoEstado.exito : TonoEstado.aviso,
              ),
            ],
          ),
          const SizedBox(height: Espacios.xs),
          Text(
            '${formatearFechaLarga(fechaEnMexico(reserva.inicio))} · '
            '${horaEnMexico(reserva.inicio)}',
            style: tema.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
