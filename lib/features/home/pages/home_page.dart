import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../negocios/data/negocios_service.dart';
import '../../negocios/pages/lista_negocios_page.dart';
import '../../perfil/data/perfil_cliente_service.dart';
import '../../perfil/pages/mi_perfil_page.dart';
import '../../reservas/data/reservas_service.dart';
import '../../reservas/pages/actividad_screen.dart';
import '../../reservas/pages/mis_reservas_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onCerrarSesion,
    this.negociosService,
    this.authService,
    this.perfilClienteService,
    this.reservasService,
    this.onSolicitarLogin,
  });

  final NegociosService? negociosService;
  final AuthService? authService;
  final PerfilClienteService? perfilClienteService;
  final ReservasService? reservasService;
  final VoidCallback onCerrarSesion;
  final VoidCallback? onSolicitarLogin;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _indiceActual = 0;
  late final AuthService _auth;
  late final List<Key> _clavesPantallas;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _clavesPantallas = List<Key>.generate(4, (_) => UniqueKey());
  }

  void _seleccionar(int nuevoIndice) {
    if (nuevoIndice == 3 && _auth.usuarioActual == null) {
      widget.onSolicitarLogin?.call();
      return;
    }

    setState(() {
      if (nuevoIndice == 2) {
        _clavesPantallas[nuevoIndice] = UniqueKey();
      }
      _indiceActual = nuevoIndice;
    });
  }

  String _obtenerInicialUsuario() {
    final usuario = _auth.usuarioActual;
    final nombre = usuario?.displayName?.trim() ?? '';

    if (nombre.isNotEmpty) return nombre[0].toUpperCase();

    final correo = usuario?.email?.trim() ?? '';
    if (correo.isNotEmpty) return correo[0].toUpperCase();

    return 'J';
  }

  @override
  Widget build(BuildContext context) {
    final estaLogueado = _auth.usuarioActual != null;
    final inicial = _obtenerInicialUsuario();

    final pantallas = <Widget>[
      ListaNegocios(
        key: _clavesPantallas[0],
        negociosService: widget.negociosService,
      ),

      ListaNegocios(
        key: _clavesPantallas[1],
        negociosService: widget.negociosService,
      ),

      if (estaLogueado)
        MisReservasPage(
          key: _clavesPantallas[2],
          authService: _auth,
          reservasService: widget.reservasService,
        )
      else
        ActividadScreen(
          key: _clavesPantallas[2],
          onBuscarLugares: () => _seleccionar(0),
          onIniciarSesion: widget.onSolicitarLogin,
        ),

      if (estaLogueado)
        MiPerfilPage(
          key: _clavesPantallas[3],
          authService: _auth,
          perfilClienteService: widget.perfilClienteService,
        )
      else
        SizedBox.shrink(key: _clavesPantallas[3]),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: IndexedStack(index: _indiceActual, children: pantallas),
      bottomNavigationBar: _BarraNavegacionInferior(
        indiceActual: _indiceActual,
        inicialUsuario: inicial,
        estaLogueado: estaLogueado,
        onSeleccionar: _seleccionar,
      ),
    );
  }
}

class _BarraNavegacionInferior extends StatelessWidget {
  const _BarraNavegacionInferior({
    required this.indiceActual,
    required this.inicialUsuario,
    required this.estaLogueado,
    required this.onSeleccionar,
  });

  final int indiceActual;
  final String inicialUsuario;
  final bool estaLogueado;
  final ValueChanged<int> onSeleccionar;

  static const _colorActivo = Color(0xFF7C3AED);
  static const _colorInactivo = Color(0xFF111827);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              _ItemBarra(
                etiqueta: 'Inicio',
                seleccionado: indiceActual == 0,
                icono: Icon(
                  indiceActual == 0 ? Icons.home_rounded : Icons.home_outlined,
                  size: 26,
                  color: indiceActual == 0 ? _colorActivo : _colorInactivo,
                ),
                onTap: () => onSeleccionar(0),
              ),

              _ItemBarra(
                etiqueta: 'Buscar',
                seleccionado: indiceActual == 1,
                icono: Icon(
                  Icons.search_rounded,
                  size: 26,
                  color: indiceActual == 1 ? _colorActivo : _colorInactivo,
                ),
                onTap: () => onSeleccionar(1),
              ),

              _ItemBarra(
                etiqueta: 'Actividad',
                seleccionado: indiceActual == 2,
                icono: Icon(
                  indiceActual == 2
                      ? Icons.calendar_today_rounded
                      : Icons.calendar_today_outlined,
                  size: 24,
                  color: indiceActual == 2 ? _colorActivo : _colorInactivo,
                ),
                onTap: () => onSeleccionar(2),
              ),

              _ItemBarra(
                etiqueta: 'Perfil',
                seleccionado: indiceActual == 3,
                icono: estaLogueado
                    ? Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 142, 69, 184),
                          shape: BoxShape.circle,
                          border: indiceActual == 3
                              ? Border.all(color: _colorActivo, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          inicialUsuario,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.person_outline_rounded,
                        size: 27,
                        color: indiceActual == 3
                            ? _colorActivo
                            : _colorInactivo,
                      ),
                onTap: () => onSeleccionar(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemBarra extends StatelessWidget {
  const _ItemBarra({
    required this.etiqueta,
    required this.seleccionado,
    required this.icono,
    required this.onTap,
  });

  final String etiqueta;
  final bool seleccionado;
  final Widget icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorTexto = seleccionado
        ? const Color(0xFF7C3AED)
        : const Color(0xFF111827);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 28, child: Center(child: icono)),
            const SizedBox(height: 4),
            Text(
              etiqueta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w500,
                color: colorTexto,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
