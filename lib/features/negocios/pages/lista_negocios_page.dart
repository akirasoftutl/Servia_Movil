import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../data/categoria.dart';
import '../data/negocio_resumen.dart';
import '../data/negocios_service.dart';
import '../mensajes.dart';
import 'filtros_negocios.dart';
import 'pie_lista.dart';
import 'tarjeta_negocio.dart';

enum _EstadoLista { cargando, error, lista }

class ListaNegociosPage extends StatelessWidget {
  const ListaNegociosPage({super.key, this.negociosService});
  final NegociosService? negociosService;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(MensajesNegocios.tituloLista)),
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
  int _version = 0;
  final _items = <NegocioResumen>[];
  List<Categoria> _categorias = [];
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
    // Invalida también durante la espera las respuestas de la consulta anterior.
    setState(() {
      _version++;
      _siguiente = null;
    });
    _espera = Timer(_esperaBusqueda, _reiniciar);
  }

  void _reiniciar() {
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
  }

  void _limpiarBusqueda() {
    _texto.clear();
    _reiniciar();
  }

  void _elegirCategoria(String? id) {
    setState(() => _categoriaId = id);
    _reiniciar();
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
      // El catálogo no impide consultar la lista (D4).
    }
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

  String _nombreCategoria(String id) {
    for (final categoria in _categorias) {
      if (categoria.id == id) return categoria.nombre;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      FiltrosNegocios(
        texto: _texto,
        categorias: _categorias,
        categoriaId: _categoriaId,
        onTexto: _alEscribir,
        onLimpiar: _limpiarBusqueda,
        onCategoria: _elegirCategoria,
      ),
      Expanded(child: _contenido()),
    ],
  );

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
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.only(top: Espacios.xs, bottom: Espacios.xl),
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
            return TarjetaNegocio(
              negocio: negocio,
              categoria: _nombreCategoria(negocio.categoriaId),
            );
          },
        );
    }
  }
}
