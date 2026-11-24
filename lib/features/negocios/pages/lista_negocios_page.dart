import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../data/categoria.dart';
import '../data/negocio_resumen.dart';
import '../data/negocios_service.dart';
import '../data/orden_negocios.dart';
import '../mensajes.dart';
import 'perfil_negocio_page.dart';
import 'pie_lista.dart';
import 'seccion_destacados.dart';
import 'selector_orden_negocios.dart';

enum _EstadoLista { cargando, error, lista }

class ListaNegociosPage extends StatelessWidget {
  const ListaNegociosPage({super.key, this.negociosService});
  final NegociosService? negociosService;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: ListaNegocios(negociosService: negociosService),
  );
}

class ListaNegocios extends StatefulWidget {
  const ListaNegocios({super.key, this.negociosService});
  final NegociosService? negociosService;

  @override
  State<ListaNegocios> createState() => _ListaNegociosState();
}

class _ListaNegociosState extends State<ListaNegocios> {
  static const _esperaBusqueda = Duration(milliseconds: 400);
  static const _distanciaCarga = 200;
  static const _maximoPaginasVacias = 5;

  late final NegociosService _service;
  final _scroll = ScrollController();
  final _texto = TextEditingController();
  Timer? _espera;
  String? _consulta;
  String? _categoriaId;
  OrdenNegocios _orden = OrdenNegocios.nombre;
  int _version = 0;
  final _items = <NegocioResumen>[];
  List<Categoria> _categorias = [];
  // Destacados de la API (HU-C26). Se cargan aparte de la lista: si fallan o
  // vienen vacíos la sección no aparece y no se muestra ningún error.
  List<NegocioResumen> _destacados = const [];
  int _versionDestacados = 0;
  _EstadoLista _estado = _EstadoLista.cargando;
  String? _siguiente;
  String? _cursorPendiente;
  Object? _error;
  bool _cargandoPagina = false;
  bool _requiereContinuar = false;

  @override
  void initState() {
    super.initState();
    _service = widget.negociosService ?? NegociosService();
    _scroll.addListener(_alDesplazarse);
    _cargar();
    _cargarCategorias();
    _cargarDestacados();
  }

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String? get _textoConsulta {
    final texto = _texto.text.trim();
    return texto.length < 2 ? null : texto;
  }

  void _alEscribir(String _) {
    _espera?.cancel();
    setState(() {
      _version++;
      _siguiente = null;
    });
    _espera = Timer(_esperaBusqueda, _reiniciar);
  }

  /// [destacados] es falso solo al cambiar el orden, que no los afecta. Con
  /// una búsqueda o una categoría la sección está oculta: no se consulta.
  void _reiniciar({bool destacados = true}) {
    _espera?.cancel();
    setState(() {
      _version++;
      _consulta = _textoConsulta;
      _siguiente = null;
      _cursorPendiente = null;
      _error = null;
      _cargandoPagina = false;
      _items.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _cargar();
    if (destacados && _consulta == null && _categoriaId == null) {
      _cargarDestacados();
    }
  }

  void _limpiarBusqueda() {
    _texto.clear();
    _reiniciar();
  }

  void _elegirCategoria(String? id) {
    setState(() => _categoriaId = id);
    _reiniciar();
  }

  /// El cursor solo vale con el orden con el que se obtuvo: al cambiarlo se
  /// reinicia la lista, y `_version` descarta lo que siga en vuelo.
  void _elegirOrden(OrdenNegocios orden) {
    if (orden == _orden) return;
    setState(() => _orden = orden);
    _reiniciar(destacados: false);
  }

  void _alDesplazarse() {
    if (_scroll.position.extentAfter < _distanciaCarga &&
        _siguiente != null &&
        _error == null) {
      _cargar(siguientePagina: true);
    }
  }

  Future<void> _cargarCategorias() async {
    try {
      final categorias = await _service.obtenerCategorias();
      if (!mounted) return;
      setState(
        () =>
            _categorias = categorias.where((c) => c.activo).toList()
              ..sort((a, b) => a.orden.compareTo(b.orden)),
      );
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _cargarDestacados() async {
    final version = ++_versionDestacados;
    List<NegocioResumen> destacados;
    try {
      destacados = await _service.obtenerDestacados();
    } catch (_) {
      destacados = const [];
    }
    if (!mounted || version != _versionDestacados) return;
    setState(() => _destacados = destacados);
  }

  Future<void> _cargar({bool siguientePagina = false}) async {
    if (_cargandoPagina) return;
    final version = _version;
    _iniciarCarga(siguientePagina);
    try {
      final pagina = await _pedirPaginaConItems(_cursorPendiente, version);
      if (!mounted || version != _version || pagina == null) return;
      _mostrarPagina(pagina, siguientePagina);
    } catch (error) {
      if (!mounted || version != _version) return;
      _mostrarError(error, siguientePagina);
    }
  }

  void _iniciarCarga(bool siguientePagina) {
    setState(() {
      if (_error == null) {
        _cursorPendiente = siguientePagina ? _siguiente : null;
      }
      _cargandoPagina = true;
      _requiereContinuar = false;
      _error = null;
      if (!siguientePagina || _items.isEmpty) {
        _estado = _EstadoLista.cargando;
      }
    });
  }

  Future<PaginaNegocios?> _pedirPaginaConItems(
    String? cursor,
    int version,
  ) async {
    var vacias = 0;
    while (vacias < _maximoPaginasVacias) {
      setState(() => _cursorPendiente = cursor);
      final pagina = await _service.listarNegocios(
        cursor: cursor,
        q: _consulta,
        categoriaId: _categoriaId,
        orden: _orden,
      );
      if (!mounted || version != _version) return null;
      if (pagina.siguiente != null && pagina.siguiente == cursor) {
        throw const FormatException('La paginación no avanzó.');
      }
      if (pagina.items.isNotEmpty || pagina.siguiente == null) return pagina;
      cursor = pagina.siguiente;
      vacias++;
    }
    return PaginaNegocios(items: const [], siguiente: cursor);
  }

  void _mostrarPagina(PaginaNegocios pagina, bool siguientePagina) {
    setState(() {
      if (!siguientePagina) _items.clear();
      _items.addAll(pagina.items);
      _siguiente = pagina.siguiente;
      _requiereContinuar = pagina.items.isEmpty && pagina.siguiente != null;
      _cargandoPagina = false;
      _estado = _EstadoLista.lista;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_requiereContinuar && _scroll.hasClients) {
        _alDesplazarse();
      }
    });
  }

  void _mostrarError(Object error, bool siguientePagina) {
    setState(() {
      _error = error;
      _cargandoPagina = false;
      if (!siguientePagina || _items.isEmpty) {
        _estado = _EstadoLista.error;
      }
    });
  }

  Widget _continuacion() => TextButton(
    onPressed: () => _cargar(siguientePagina: true),
    child: const Text(MensajesNegocios.cargarMas),
  );

  String? _nombreCategoria(String? id) {
    if (id == null) return null;
    for (final categoria in _categorias) {
      if (categoria.id == id) return categoria.nombre;
    }
    return id;
  }

  String? _imagenDeNegocio(NegocioResumen negocio) {
    final url = negocio.imagenUrl;
    return url != null && url.isNotEmpty ? url : null;
  }

  void _abrirDetalleNegocio(NegocioResumen negocio) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PerfilNegocioPage(negocioId: negocio.id, negociosService: _service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _EncabezadoExploracion(
              controller: _texto,
              onChanged: _alEscribir,
              onLimpiar: _limpiarBusqueda,
              onBuscar: _reiniciar,
              orden: _orden,
              onOrden: _elegirOrden,
            ),
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  /// Ni con una búsqueda (aplicada o a medio escribir) ni con una categoría.
  bool get _hayDestacados =>
      _destacados.isNotEmpty &&
      _consulta == null &&
      _textoConsulta == null &&
      _categoriaId == null;

  Widget _contenido() {
    switch (_estado) {
      case _EstadoLista.cargando:
        return const EstadoCargando();
      case _EstadoLista.error:
        return EstadoError(
          mensaje: MensajesNegocios.mensajeDeErrorBusqueda(_error!),
          onReintentar: MensajesNegocios.puedeReintentarBusqueda(_error!)
              ? _cargar
              : null,
        );
      case _EstadoLista.lista:
        if (_items.isEmpty) {
          if (_requiereContinuar) return Center(child: _continuacion());
          final filtrada = _consulta != null || _categoriaId != null;
          return EstadoVacio(
            icono: filtrada ? Icons.search_off : Icons.storefront_outlined,
            mensaje: filtrada
                ? MensajesNegocios.sinResultados
                : MensajesNegocios.listaVacia,
          );
        }

        // Si el usuario está buscando, mostramos la lista directa de resultados
        if (_consulta != null) {
          return ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, Espacios.xl),
            itemCount: _items.length + 1,
            itemBuilder: (context, indice) {
              if (indice == _items.length) {
                if (_requiereContinuar) return _continuacion();
                return PieLista(
                  cargando: _cargandoPagina,
                  error: _error,
                  onReintentar: () => _cargar(siguientePagina: true),
                );
              }
              final negocio = _items[indice];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _TarjetaNegocioHorizontal(
                  negocio: negocio,
                  categoria: _nombreCategoria(negocio.categoriaId),
                  imagenUrl: _imagenDeNegocio(negocio),
                  onTap: () => _abrirDetalleNegocio(negocio),
                ),
              );
            },
          );
        }

        // Vista principal estilo Fresha: secciones horizontales + lista "Lugares cercanos"
        final nuevos = _items.length > 2
            ? _items.skip(1).take(5).toList()
            : _items;

        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.only(top: 8, bottom: Espacios.xxl),
          children: [
            if (_categorias.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _CuadriculaCategorias(
                  categorias: _categorias,
                  categoriaSeleccionadaId: _categoriaId,
                  onSeleccionar: _elegirCategoria,
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_hayDestacados) ...[
              SeccionDestacados(
                negocios: _destacados,
                nombreCategoria: _nombreCategoria,
                onAbrir: _abrirDetalleNegocio,
              ),
              const SizedBox(height: Espacios.xl),
            ],

            // Sección 2: Nuevo en Servia (Carrusel horizontal)
            const _TituloSeccion(titulo: 'Nuevo en Servia'),
            const SizedBox(height: 12),
            SizedBox(
              height: 252,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: nuevos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final negocio = nuevos[i];
                  return _TarjetaNegocioCarrusel(
                    negocio: negocio,
                    categoria: _nombreCategoria(negocio.categoriaId),
                    imagenUrl: _imagenDeNegocio(negocio),
                    etiquetaSuperior: 'Nuevo',
                    onTap: () => _abrirDetalleNegocio(negocio),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Sección 3: Lugares cercanos (Lista vertical con todas las tarjetas + paginación infinita)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Expanded: con texto grande el título baja de línea en
                  // lugar de desbordar la fila.
                  Expanded(
                    child: Text(
                      'Lugares cercanos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Text(
                    'Ver todo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    _TarjetaNegocioHorizontal(
                      negocio: _items[i],
                      categoria: _nombreCategoria(_items[i].categoriaId),
                      imagenUrl: _imagenDeNegocio(_items[i]),
                      onTap: () => _abrirDetalleNegocio(_items[i]),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_requiereContinuar)
                    _continuacion()
                  else
                    PieLista(
                      cargando: _cargandoPagina,
                      error: _error,
                      onReintentar: () => _cargar(siguientePagina: true),
                    ),
                ],
              ),
            ),
          ],
        );
    }
  }
}

/// Encabezado superior: Ubicación actual + Barra de búsqueda tipo píldora con botón negro
class _EncabezadoExploracion extends StatelessWidget {
  const _EncabezadoExploracion({
    required this.controller,
    required this.onChanged,
    required this.onLimpiar,
    required this.onBuscar,
    required this.orden,
    required this.onOrden,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onLimpiar;
  final VoidCallback onBuscar;
  final OrdenNegocios orden;
  final ValueChanged<OrdenNegocios> onOrden;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En pantallas angostas o con texto grande el selector baja a su
          // propia línea en lugar de desbordar.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: Espacios.m,
            runSpacing: Espacios.s,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: 18,
                    color: Color.fromARGB(255, 145, 90, 240),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Ubicación actual',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(width: 2),
                ],
              ),
              SelectorOrdenNegocios(orden: orden, onOrden: onOrden),
            ],
          ),
          const SizedBox(height: Espacios.s),

          // Barra de búsqueda tipo píldora flotante
          Container(
            height: 62,
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF111827),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  // Área táctil de al menos 48 dp, también con texto escalado.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      onSubmitted: (_) => onBuscar(),
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Explorar todos los servicios',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      onPressed: onLimpiar,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      constraints: const BoxConstraints(),
                    );
                  },
                ),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton(
                    onPressed: onBuscar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F0F0F),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Buscar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CuadriculaCategorias extends StatelessWidget {
  const _CuadriculaCategorias({
    required this.categorias,
    required this.categoriaSeleccionadaId,
    required this.onSeleccionar,
  });

  final List<Categoria> categorias;
  final String? categoriaSeleccionadaId;
  final ValueChanged<String?> onSeleccionar;

  IconData _iconoParaCategoria(String id) {
    switch (id) {
      case 'cabello-barba':
        return Icons.content_cut_rounded;
      case 'estetica-facial-corporal':
        return Icons.face_retouching_natural_outlined;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'maquillaje-imagen':
        return Icons.brush_outlined;
      case 'unas-pestanas-cejas':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  String _etiquetaCorta(Categoria categoria) {
    return categoria.nombre;
  }

  @override
  Widget build(BuildContext context) {
    if (categorias.isEmpty) return const SizedBox.shrink();

    final elementos = <_ItemCategoriaUI>[
      const _ItemCategoriaUI(
        id: null,
        nombre: 'Todo',
        icono: Icons.grid_view_rounded,
      ),
      for (final cat in categorias)
        _ItemCategoriaUI(
          id: cat.id,
          nombre: _etiquetaCorta(cat),
          icono: _iconoParaCategoria(cat.id),
        ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      itemCount: elementos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (context, index) {
        final item = elementos[index];
        final seleccionada = categoriaSeleccionadaId == item.id;

        return GestureDetector(
          onTap: () => onSeleccionar(item.id),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: seleccionada
                        ? const Color(0xFFF0EDFA)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(
                      color: seleccionada
                          ? const Color(0xFFDCD2F5)
                          : const Color(0xFFE5E5E5),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      item.icono,
                      size: 34,
                      color: const Color(0xFF111111),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  item.nombre,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.25,
                    fontWeight: seleccionada
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemCategoriaUI {
  const _ItemCategoriaUI({
    required this.id,
    required this.nombre,
    required this.icono,
  });

  final String? id;
  final String nombre;
  final IconData icono;
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _TarjetaNegocioCarrusel extends StatelessWidget {
  const _TarjetaNegocioCarrusel({
    required this.negocio,
    required this.categoria,
    required this.imagenUrl,
    required this.etiquetaSuperior,
    required this.onTap,
  });

  final NegocioResumen negocio;
  final String? categoria;
  final String? imagenUrl;
  final String etiquetaSuperior;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 265,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen con esquinas redondeadas, badge superior y corazón
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _ImagenPortada(
                    url: imagenUrl,
                    width: 265,
                    height: 165,
                    iconSize: 40,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      etiquetaSuperior,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: Text(
                    negocio.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 2),
                const Text(
                  '4.9',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 2),

            // Categoría y estado de reservas
            Flexible(
              child: Text(
                [
                  ?categoria,
                  if (negocio.aceptaReservas) 'Disponible',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta horizontal para la sección "Lugares cercanos" y resultados de búsqueda
class _TarjetaNegocioHorizontal extends StatelessWidget {
  const _TarjetaNegocioHorizontal({
    required this.negocio,
    required this.categoria,
    required this.imagenUrl,
    required this.onTap,
  });

  final NegocioResumen negocio;
  final String? categoria;
  final String? imagenUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(15),
              ),
              child: _ImagenPortada(
                url: imagenUrl,
                width: 108,
                height: 108,
                iconSize: 24,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            negocio.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.favorite_border_rounded,
                          size: 18,
                          color: Color(0xFF9CA3AF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 15,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 3),
                        const Text(
                          '5.0',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (categoria != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '· $categoria',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Portada del negocio en la lista. Sin URL (o si falla la carga) muestra el
/// mismo marcador que ya se usaba para los errores de imagen.
class _ImagenPortada extends StatelessWidget {
  const _ImagenPortada({
    required this.url,
    required this.width,
    required this.height,
    required this.iconSize,
  });

  final String? url;
  final double width;
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    Widget marcador() => Container(
      width: width,
      height: height,
      color: const Color(0xFFF3F4F6),
      child: Icon(
        Icons.storefront_outlined,
        size: iconSize,
        color: const Color(0xFF9CA3AF),
      ),
    );

    if (url == null || url!.isEmpty) return marcador();

    return Image.network(
      url!,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => marcador(),
    );
  }
}
