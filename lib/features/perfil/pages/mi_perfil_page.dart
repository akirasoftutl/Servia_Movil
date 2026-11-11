import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/mensajes.dart';
import '../../auth/pages/cambiar_contrasena_page.dart';
import '../../auth/validaciones.dart';
import '../data/perfil_cliente.dart';
import '../data/perfil_cliente_service.dart';
import '../mensajes.dart';

/// «Mi perfil» (MVP-05): el cliente ve y edita su nombre, correo y teléfono.
/// Lee y guarda con la API (`/usuarios/yo`); nunca escribe en Firestore.
/// Los estilos salen del tema (Theme.of) y de los componentes de Material 3.
class MiPerfilPage extends StatefulWidget {
  const MiPerfilPage({super.key, this.authService, this.perfilClienteService});

  final AuthService? authService;
  final PerfilClienteService? perfilClienteService;

  @override
  State<MiPerfilPage> createState() => _MiPerfilPageState();
}

class _MiPerfilPageState extends State<MiPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();

  late final AuthService _auth;
  late final PerfilClienteService _servicio;

  PerfilCliente? _perfil;
  bool _cargando = true;
  bool _editando = false;
  bool _guardando = false;
  String? _errorCarga;
  String? _errorGeneral;
  String? _errorCorreo;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _servicio = widget.perfilClienteService ?? PerfilClienteService();
    _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _telefono.dispose();
    super.dispose();
  }

  String _mensajeDe(Object error) =>
      error is ApiException ? error.mensaje : MensajesAuth.errorRed;

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final usuario = _auth.usuarioActual;
      if (usuario == null) {
        throw ApiException(401, MensajesPerfil.sesionInvalida);
      }
      final token = await usuario.getIdToken();
      final perfil = await _servicio.obtener(token!);
      if (!mounted) return;
      setState(() {
        _perfil = perfil;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorCarga = _mensajeDe(error);
        _cargando = false;
      });
    }
  }

  void _editar() {
    final perfil = _perfil!;
    _nombre.text = perfil.nombre;
    _correo.text = perfil.correo;
    _telefono.text = perfil.telefono;
    setState(() {
      _editando = true;
      _errorGeneral = null;
      _errorCorreo = null;
    });
  }

  void _cancelar() {
    setState(() {
      _editando = false;
      _errorGeneral = null;
      _errorCorreo = null;
    });
  }

  void _abrirCambioContrasena() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CambiarContrasenaPage(authService: _auth),
      ),
    );
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    setState(() {
      _errorGeneral = null;
      _errorCorreo = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final actual = _perfil!;
    final nombre = _nombre.text.trim();
    final telefono = _telefono.text.trim();
    final correo = _correo.text.trim();
    final cambiaNombre = nombre != actual.nombre;
    final cambiaTelefono = telefono != actual.telefono;
    final cambiaCorreo = correo.toLowerCase() != actual.correo.toLowerCase();

    if (!cambiaNombre && !cambiaTelefono && !cambiaCorreo) {
      _cancelar();
      return;
    }

    setState(() => _guardando = true);
    try {
      final usuario = _auth.usuarioActual;
      if (usuario == null) {
        throw ApiException(401, MensajesPerfil.sesionInvalida);
      }
      final token = await usuario.getIdToken();
      final nuevo = await _servicio.actualizar(
        token!,
        nombre: cambiaNombre ? nombre : null,
        telefono: cambiaTelefono ? telefono : null,
        correo: cambiaCorreo ? correo : null,
      );
      if (!mounted) return;
      setState(() {
        _perfil = nuevo;
        _editando = false;
        _guardando = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(MensajesPerfil.guardado)));
      if (cambiaCorreo) await _renovarToken(usuario);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        if (error is ApiException && error.statusCode == 409) {
          _errorCorreo = MensajesPerfil.correoEnUso;
        } else {
          _errorGeneral = _mensajeDe(error);
        }
      });
    }
  }

  static const _codigosSesionInvalida = {
    'user-token-expired',
    'invalid-user-token',
    'user-disabled',
    'user-not-found',
    'requires-recent-login',
  };

  /// El correo ya cambió en la API: se renueva el token para que la sesión siga.
  /// Un fallo de red no deshace el guardado ni cierra nada. Si la sesión ya no
  /// es válida, se vuelve al inicio y se pide iniciar sesión con el nuevo correo.
  Future<void> _renovarToken(User usuario) async {
    final navegador = Navigator.of(context);
    final avisos = ScaffoldMessenger.of(context);
    try {
      await usuario.getIdToken(true);
    } catch (error) {
      final sesionInvalida =
          _auth.usuarioActual == null ||
          (error is FirebaseAuthException &&
              _codigosSesionInvalida.contains(error.code));
      if (!sesionInvalida) return;
      navegador.popUntil((ruta) => ruta.isFirst);
      avisos
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(MensajesPerfil.iniciaConNuevoCorreo)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(MensajesPerfil.titulo)),
      body: _cuerpo(context),
    );
  }

  Widget _cuerpo(BuildContext context) {
    if (_cargando) {
      return const EstadoCargando();
    }
    if (_perfil == null) {
      return EstadoError(
        mensaje: _errorCarga ?? MensajesAuth.errorRed,
        onReintentar: _cargar,
      );
    }
    return _editando ? _formulario(context) : _vista(_perfil!);
  }

  Widget _vista(PerfilCliente perfil) {
    final tema = Theme.of(context);
    Widget dato(IconData icono, String etiqueta, String valor) => ListTile(
      leading: Icon(icono),
      title: Text(etiqueta),
      subtitle: Text(valor),
      // Etiqueta pequeña arriba y el dato con más peso.
      titleTextStyle: tema.textTheme.bodySmall,
      subtitleTextStyle: tema.textTheme.titleMedium,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Espacios.l,
        Espacios.s,
        Espacios.l,
        Espacios.xxl,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Espacios.xs),
            child: Column(
              children: [
                dato(Icons.person_outline, 'Nombre', perfil.nombre),
                const Divider(indent: Espacios.l, endIndent: Espacios.l),
                dato(Icons.mail_outline, 'Correo', perfil.correo),
                const Divider(indent: Espacios.l, endIndent: Espacios.l),
                dato(Icons.phone_outlined, 'Teléfono', perfil.telefono),
              ],
            ),
          ),
        ),
        const SizedBox(height: Espacios.xl),
        FilledButton(onPressed: _editar, child: const Text('Editar')),
        const SizedBox(height: Espacios.s),
        OutlinedButton.icon(
          onPressed: _abrirCambioContrasena,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Cambiar contraseña'),
        ),
      ],
    );
  }

  Widget _formulario(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Espacios.l,
          Espacios.m,
          Espacios.l,
          Espacios.xxl,
        ),
        children: [
          if (_errorGeneral != null) ...[
            Aviso(texto: _errorGeneral!),
            const SizedBox(height: Espacios.l),
          ],
          TextFormField(
            controller: _nombre,
            enabled: !_guardando,
            textCapitalization: TextCapitalization.words,
            validator: ValidacionesCliente.nombre,
            decoration: const InputDecoration(labelText: 'Nombre completo'),
          ),
          const SizedBox(height: Espacios.l),
          TextFormField(
            controller: _correo,
            enabled: !_guardando,
            keyboardType: TextInputType.emailAddress,
            validator: ValidacionesCliente.correo,
            onChanged: (_) {
              if (_errorCorreo != null) setState(() => _errorCorreo = null);
            },
            decoration: InputDecoration(
              labelText: 'Correo',
              errorText: _errorCorreo,
            ),
          ),
          const SizedBox(height: Espacios.l),
          TextFormField(
            controller: _telefono,
            enabled: !_guardando,
            keyboardType: TextInputType.phone,
            validator: ValidacionesCliente.telefono,
            decoration: const InputDecoration(
              labelText: 'Teléfono (10 dígitos)',
            ),
          ),
          const SizedBox(height: Espacios.xl),
          FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: Text(_guardando ? 'Guardando...' : 'Guardar'),
          ),
          const SizedBox(height: Espacios.s),
          TextButton(
            onPressed: _guardando ? null : _cancelar,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
