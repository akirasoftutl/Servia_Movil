import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../data/negocio_cercano.dart';
import '../data/negocios_service.dart';
import '../data/ubicacion_cliente.dart';
import '../mensajes.dart';
import 'hoja_inicio.dart';
import 'lista_negocios_page.dart';
import 'mapa_cercanos.dart';
import 'marcador_mapa.dart';

// Literales del rediseño ya usados en «Cerca de ti» y en las tarjetas.
const _margen = 20.0;
const _texto = Color(0xFF111827);
const _borde = Color(0xFFE5E7EB);
const _bordeBoton = Color(0xFFD1D5DB);
const _estiloMensaje = TextStyle(fontSize: 14, color: Color(0xFF6B7280));

/// Parte del alto que el mapa deja a la vista con la hoja abierta.
const _fraccionMapa = 0.36;

/// Alto aproximado de la búsqueda mientras no se ha medido.
const _encabezadoEstimado = 130.0;

/// Inicio con el mapa de negocios cercanos de fondo y el contenido del inicio
/// (búsqueda, categorías, secciones) en una hoja que se desliza encima.
///
/// La posición del cliente vive solo en memoria mientras se muestra el mapa:
/// no se guarda ni se registra. Sin permiso, sin posición o sin negocios con
/// ubicación válida no hay mapa y la hoja ocupa todo, como antes.
class InicioConMapa extends StatefulWidget {
  const InicioConMapa({
    super.key,
    this.negociosService,
    this.proveedorUbicacion,
    this.constructorMapa,
  });

  final NegociosService? negociosService;
  final ProveedorUbicacionCliente? proveedorUbicacion;
  final ConstructorMapaCercanos? constructorMapa;

  @override
  State<InicioConMapa> createState() => _InicioConMapaState();
}

class _InicioConMapaState extends State<InicioConMapa>
    with SingleTickerProviderStateMixin {
  late final NegociosService _service =
      widget.negociosService ?? NegociosService();
  late final ProveedorUbicacionCliente _ubicacion =
      widget.proveedorUbicacion ?? UbicacionCliente().obtener;
  late final AnimationController _hoja = AnimationController(
    vsync: this,
    value: 1,
  )..addStatusListener(_alAsentarHoja);
  final _claveLista = GlobalKey();
  final _claveEncabezado = GlobalKey();

  bool _cargando = false;
  bool _error = false;
  // Posición efímera solo en memoria; se reemplaza en cada lectura.
  PosicionCliente? _posicion;
  List<NegocioCercano> _negocios = const [];
  String? _seleccionadoId;
  double _alturaEncabezado = _encabezadoEstimado;
  bool _hojaAbiertaEnReposo = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _hoja.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = false;
      _seleccionadoId = null;
    });
    PosicionCliente? posicion;
    try {
      posicion = await _ubicacion();
    } catch (_) {
      posicion = null;
    }
    if (!mounted) return;
    if (posicion == null) {
      setState(() {
        _posicion = null;
        _negocios = const [];
        _cargando = false;
      });
      return;
    }
    setState(() => _posicion = posicion);
    try {
      final negocios = await _service.obtenerCercanos(
        lat: posicion.lat,
        lng: posicion.lng,
      );
      if (!mounted) return;
      setState(() {
        _negocios = negocios;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _cargando = false;
      });
    }
  }

  void _alAsentarHoja(AnimationStatus estado) {
    if (!estado.isCompleted && !estado.isDismissed) return;
    final abierta = estado.isCompleted;
    if (abierta != _hojaAbiertaEnReposo) {
      setState(() => _hojaAbiertaEnReposo = abierta);
    }
  }

  void _alSeleccionarPin(String negocioId) =>
      setState(() => _seleccionadoId = negocioId);

  void _alTocarMapa() {
    if (_seleccionadoId != null) setState(() => _seleccionadoId = null);
  }

  /// Mide la búsqueda tras dibujarla: es lo que queda a la vista al colapsar.
  void _medirEncabezado(Duration _) {
    if (!mounted) return;
    final caja = _claveEncabezado.currentContext?.findRenderObject();
    if (caja is! RenderBox || !caja.hasSize) return;
    final alto = caja.size.height;
    if ((alto - _alturaEncabezado).abs() > 0.5) {
      setState(() => _alturaEncabezado = alto);
    }
  }

  List<PinNegocioMapa> get _pines => [
    for (final cercano in _negocios)
      if (cercano.ubicacion case final ubicacion?)
        PinNegocioMapa(
          cercano: cercano,
          ubicacion: ubicacion,
          seleccionado: cercano.negocio.id == _seleccionadoId,
        ),
  ];

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_medirEncabezado);
    final posicion = _posicion;
    final pines = _pines;
    final conMapa =
        posicion != null &&
        (_cargando || _error || _negocios.isEmpty || pines.isNotEmpty);
    final margenSuperior = MediaQuery.paddingOf(context).top;

    final hoja = MediaQuery.removePadding(
      context: context,
      removeTop: conMapa,
      child: ListaNegocios(
        key: _claveLista,
        negociosService: _service,
        enHoja: conMapa,
        claveEncabezado: _claveEncabezado,
      ),
    );

    return ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, limites) {
          final alto = limites.maxHeight;
          final topAbierta = conMapa ? alto * _fraccionMapa : 0.0;
          final topColapsada = conMapa
              ? math.max(topAbierta, alto - Medidas.tactil - _alturaEncabezado)
              : 0.0;
          final recorrido = topColapsada - topAbierta;

          final Widget? mapa;
          if (posicion != null && conMapa) {
            final visibleEnReposo =
                alto - (_hojaAbiertaEnReposo ? topAbierta : topColapsada);
            final constructor = widget.constructorMapa ?? construirMapaCercanos;
            mapa = Semantics(
              container: true,
              explicitChildNodes: true,
              label: MensajesNegocios.descripcionMapaCercanos,
              child: constructor(
                context,
                DatosMapaCercanos(
                  posicionCliente: posicion,
                  pines: pines,
                  seleccionadoId: _seleccionadoId,
                  zoomInicial: calcularZoomInicial(
                    posicion,
                    pines.map((pin) => pin.ubicacion),
                  ),
                  onSeleccionarPin: _alSeleccionarPin,
                  onTocarMapa: _alTocarMapa,
                  padding: EdgeInsets.only(
                    top: margenSuperior + Medidas.tactil + Espacios.m,
                    bottom: visibleEnReposo,
                  ),
                ),
              ),
            );
          } else {
            mapa = null;
          }

          final Widget? aviso =
              conMapa && (_cargando || _error || pines.isEmpty)
              ? _AvisoCercanos(
                  cargando: _cargando,
                  error: _error,
                  onReintentar: _cargar,
                )
              : null;

          return AnimatedBuilder(
            animation: _hoja,
            child: HojaInicio(
              progreso: _hoja,
              recorrido: recorrido,
              activa: conMapa,
              child: hoja,
            ),
            builder: (context, hoja) {
              final top = conMapa
                  ? lerpDouble(topColapsada, topAbierta, _hoja.value)!
                  : 0.0;
              final visible = alto - top;
              return Stack(
                children: [
                  if (mapa != null) Positioned.fill(child: mapa),
                  if (aviso != null)
                    Positioned(
                      left: _margen,
                      right: _margen,
                      bottom: visible + Espacios.s,
                      child: aviso,
                    ),
                  Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    height: alto - topAbierta,
                    child: hoja!,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Aviso discreto sobre el mapa mientras cargan los cercanos, si fallan o si
/// no hay ninguno: el mapa sigue a la vista con el punto del cliente.
class _AvisoCercanos extends StatelessWidget {
  const _AvisoCercanos({
    required this.cargando,
    required this.error,
    required this.onReintentar,
  });

  final bool cargando;
  final bool error;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final Widget contenido;
    if (cargando) {
      contenido = const Row(
        children: [
          SizedBox.square(
            dimension: Espacios.l,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              strokeCap: StrokeCap.round,
            ),
          ),
          SizedBox(width: Espacios.m),
          Expanded(
            child: Text(
              MensajesNegocios.buscandoCercanos,
              style: _estiloMensaje,
            ),
          ),
        ],
      );
    } else if (error) {
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(MensajesNegocios.errorCercanos, style: _estiloMensaje),
          const SizedBox(height: Espacios.s),
          OutlinedButton(
            onPressed: onReintentar,
            style: OutlinedButton.styleFrom(
              foregroundColor: _texto,
              side: const BorderSide(color: _bordeBoton),
              shape: const StadiumBorder(),
              minimumSize: const Size(Medidas.tactil, Medidas.tactil),
            ),
            child: const Text(
              MensajesNegocios.reintentar,
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    } else {
      contenido = const Text(
        MensajesNegocios.sinCercanos,
        style: _estiloMensaje,
      );
    }
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        key: const Key('aviso-cercanos'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: Radios.tarjeta,
          border: Border.all(color: _borde),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Espacios.l,
            vertical: Espacios.m,
          ),
          child: contenido,
        ),
      ),
    );
  }
}
