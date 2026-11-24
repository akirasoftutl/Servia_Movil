import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/estados.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/mensajes.dart';
import '../../auth/pages/cambiar_contrasena_page.dart';
import '../../auth/validaciones.dart';
import '../../negocios/pages/fotos_negocio.dart' show ProveedorImagenNegocio;
import '../data/perfil_cliente.dart';
import '../data/perfil_cliente_service.dart';
import '../data/selector_foto.dart';
import '../data/validacion_foto.dart';
import '../mensajes.dart';
import 'dialogo_confirmacion.dart';
import 'seccion_foto_perfil.dart';

class MiPerfilPage extends StatefulWidget {
  const MiPerfilPage({
    super.key,
    this.authService,
    this.perfilClienteService,
    this.selectorFoto,
    this.proveedorFoto,
  });

  final AuthService? authService;
  final PerfilClienteService? perfilClienteService;

  /// Galería de donde se elige la foto; las pruebas dan una simulada.
  final SelectorFoto? selectorFoto;

  /// Cómo se descarga la foto guardada; por defecto, por red.
  final ProveedorImagenNegocio? proveedorFoto;

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
  late final SelectorFoto _selector;
  late final ProveedorImagenNegocio _proveedorFoto;

  PerfilCliente? _perfil;
  // Foto de perfil (HU-C11): lo que está en curso, el error y la foto elegida
  // que falló, para reintentar sin volver a elegirla.
  String? _fotoOcupada;
  Uint8List? _vistaPrevia;
  FotoElegida? _fotoPendiente;
  String? _errorFoto;
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
    _selector = widget.selectorFoto ?? SelectorFotoGaleria();
    _proveedorFoto = widget.proveedorFoto ?? (url) => NetworkImage(url);
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

  Future<String> _token() async {
    final usuario = _auth.usuarioActual;
    if (usuario == null) throw ApiException(401, MensajesPerfil.sesionInvalida);
    return (await usuario.getIdToken())!;
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _elegirFoto() async {
    if (_fotoOcupada != null) return;
    setState(() {
      _errorFoto = null;
      _fotoPendiente = null;
    });
    final FotoElegida? foto;
    try {
      foto = await _selector.elegir();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorFoto = MensajesPerfil.fotoNoElegida);
      return;
    }
    if (!mounted || foto == null) return;
    // Se revisa antes de subir; la API vuelve a validar y decide.
    final motivo = ValidacionFoto.validar(foto.bytes);
    if (motivo != null) {
      setState(() => _errorFoto = motivo);
      return;
    }
    await _subirFoto(foto);
  }

  Future<void> _subirFoto(FotoElegida foto) async {
    if (_fotoOcupada != null) return;
    setState(() {
      _fotoOcupada = MensajesPerfil.subiendoFoto;
      _vistaPrevia = foto.bytes;
      _fotoPendiente = foto;
      _errorFoto = null;
    });
    try {
      final token = await _token();
      final nueva = await _servicio.subirFoto(token, foto.bytes, foto.nombre);
      if (!mounted) return;
      setState(() {
        _perfil = _perfil!.conFoto(nueva);
        _fotoOcupada = null;
        _vistaPrevia = null;
        _fotoPendiente = null;
      });
      _avisar(MensajesPerfil.fotoActualizada);
    } catch (error) {
      if (!mounted) return;
      // La foto anterior no cambia: solo se ofrece reintentar.
      setState(() {
        _fotoOcupada = null;
        _vistaPrevia = null;
        _errorFoto = _mensajeDe(error);
      });
    }
  }

  Future<void> _quitarFoto() async {
    if (_fotoOcupada != null) return;
    final confirmado = await confirmarAccion(
      context,
      titulo: MensajesPerfil.quitarTitulo,
      parrafos: const [MensajesPerfil.quitarCuerpo],
      textoConfirmar: MensajesPerfil.quitarFoto,
    );
    if (!confirmado || !mounted) return;
    setState(() {
      _fotoOcupada = MensajesPerfil.quitandoFoto;
      _errorFoto = null;
      _fotoPendiente = null;
    });
    try {
      await _servicio.quitarFoto(await _token());
      if (!mounted) return;
      setState(() {
        _perfil = _perfil!.conFoto(null);
        _fotoOcupada = null;
      });
      _avisar(MensajesPerfil.fotoEliminada);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _fotoOcupada = null;
        _errorFoto = _mensajeDe(error);
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
        // Editar los datos no toca la foto: si la respuesta no la trae, se
        // conserva la que ya se veía.
        _perfil = nuevo.foto == null ? nuevo.conFoto(actual.foto) : nuevo;
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

  InputDecoration _decoracionCampo({
    required String hintText,
    String? errorText,
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
      errorText: errorText,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: const Text(
          MensajesPerfil.titulo,
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
    Widget filaDato({
      required IconData icono,
      required String etiqueta,
      required String valor,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icono, size: 22, color: const Color(0xFF111827)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etiqueta,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    valor.isNotEmpty ? valor : 'Sin registrar',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            SeccionFotoPerfil(
              nombre: perfil.nombre,
              proveedor: _proveedorFoto,
              url: perfil.foto?.url,
              vistaPrevia: _vistaPrevia,
              ocupado: _fotoOcupada,
              error: _errorFoto,
              onElegir: _elegirFoto,
              onQuitar: _quitarFoto,
              onReintentar: _fotoPendiente == null
                  ? null
                  : () => _subirFoto(_fotoPendiente!),
            ),
            const SizedBox(height: Espacios.xl),
            // Encabezado: nombre grande.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        perfil.nombre,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                          height: 1.15,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Perfil personal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Column(
                children: [
                  filaDato(
                    icono: Icons.person_outline,
                    etiqueta: 'Nombre',
                    valor: perfil.nombre,
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 18,
                    color: Color(0xFFF3F4F6),
                  ),
                  filaDato(
                    icono: Icons.mail_outline,
                    etiqueta: 'Correo electrónico',
                    valor: perfil.correo,
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 18,
                    color: Color(0xFFF3F4F6),
                  ),
                  filaDato(
                    icono: Icons.phone_outlined,
                    etiqueta: 'Teléfono',
                    valor: perfil.telefono,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    onTap: () {
                      // TODO: Acción o pantalla de soporte
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.support_outlined,
                            size: 22,
                            color: Color(0xFF111827),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Soporte',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Color(0xFF9CA3AF),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 18,
                    color: Color(0xFFF3F4F6),
                  ),
                  InkWell(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                    onTap: () {
                      // TODO: Acción de idioma
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.language_outlined,
                            size: 22,
                            color: Color(0xFF111827),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Español (México)',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _editar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F0F0F),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Editar información'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _abrirCambioContrasena,
                icon: const Icon(Icons.lock_outline),
                label: const Text('Cambiar contraseña'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(
                    color: Color(0xFFD1D5DB),
                    width: 1.2,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () async {
                  await _auth.cerrarSesion();
                  if (!mounted) return;
                  Navigator.of(context).popUntil((ruta) => ruta.isFirst);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 22, color: Color(0xFFDC2626)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              const Text(
                'Editar perfil',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Actualiza tus datos personales.',
                style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 24),

              if (_errorGeneral != null) ...[
                Aviso(texto: _errorGeneral!),
                const SizedBox(height: Espacios.l),
              ],

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
                controller: _nombre,
                enabled: !_guardando,
                textCapitalization: TextCapitalization.words,
                validator: ValidacionesCliente.nombre,
                style: const TextStyle(fontSize: 16, color: Color(0xFF111827)),
                decoration: _decoracionCampo(hintText: 'Tu nombre completo'),
              ),

              const SizedBox(height: 16),

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
                controller: _correo,
                enabled: !_guardando,
                keyboardType: TextInputType.emailAddress,
                validator: ValidacionesCliente.correo,
                onChanged: (_) {
                  if (_errorCorreo != null) setState(() => _errorCorreo = null);
                },
                style: const TextStyle(fontSize: 16, color: Color(0xFF111827)),
                decoration: _decoracionCampo(
                  hintText: 'Dirección de correo electrónico',
                  errorText: _errorCorreo,
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Teléfono (10 dígitos)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _telefono,
                enabled: !_guardando,
                keyboardType: TextInputType.phone,
                validator: ValidacionesCliente.telefono,
                style: const TextStyle(fontSize: 16, color: Color(0xFF111827)),
                decoration: _decoracionCampo(hintText: 'Teléfono a 10 dígitos'),
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
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
                  child: _guardando
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _guardando ? null : _cancelar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF111827),
                    side: const BorderSide(
                      color: Color(0xFFD1D5DB),
                      width: 1.2,
                    ),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
