import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/colores_servia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../data/negocio_cercano.dart';
import '../data/negocios_service.dart';
import '../data/ubicacion_cliente.dart';
import '../data/ubicacion_negocio.dart';
import '../mensajes.dart';
import 'marcador_mapa.dart';
import 'tarjeta_negocio.dart';

// Mismos literales de los listados y tarjetas de negocios, sin modificar el tema.
const _margen = 20.0;
const _texto = Color(0xFF111827);
const _borde = Color(0xFFE5E7EB);
const _agarradera = Color(0xFFD1D5DB);

/// Pin de un negocio cercano con ubicación válida listo para pintarse en el mapa.
class PinNegocioMapa {
  const PinNegocioMapa({
    required this.cercano,
    required this.ubicacion,
    required this.seleccionado,
  });

  final NegocioCercano cercano;
  final UbicacionNegocio ubicacion;
  final bool seleccionado;

  String get id => cercano.negocio.id;
  String get etiqueta => MensajesNegocios.distanciaCorta(cercano.distanciaKm);
  String get descripcionSemantica => MensajesNegocios.descripcionPin(
    cercano.negocio.nombre,
    cercano.distanciaKm,
  );
}

/// Estado que recibe el widget del mapa (real o falso inyectado en pruebas).
class DatosMapaCercanos {
  const DatosMapaCercanos({
    required this.posicionCliente,
    required this.pines,
    required this.seleccionadoId,
    required this.zoomInicial,
    required this.onSeleccionarPin,
  });

  final PosicionCliente posicionCliente;
  final List<PinNegocioMapa> pines;
  final String? seleccionadoId;
  final double zoomInicial;
  final ValueChanged<String> onSeleccionarPin;
}

typedef ConstructorMapaCercanos =
    Widget Function(BuildContext context, DatosMapaCercanos datos);

typedef GeneradorIconoPinMapa =
    Future<BitmapDescriptor> Function({
      required String etiqueta,
      required bool seleccionado,
      required double pixelRatio,
    });

typedef GeneradorIconoClienteMapa =
    Future<BitmapDescriptor> Function({required double pixelRatio});

typedef ConstructorMapaNativo =
    Widget Function({
      required CameraPosition camaraInicial,
      required Set<Marker> marcadores,
      required EdgeInsets padding,
      required MapCreatedCallback onMapCreated,
    });

Widget _construirGoogleMap(BuildContext context, DatosMapaCercanos datos) =>
    VistaGoogleMap(datos: datos);

class MapaCercanosPage extends StatefulWidget {
  const MapaCercanosPage({
    super.key,
    this.negociosService,
    this.proveedorUbicacion,
    this.constructorMapa,
  });

  final NegociosService? negociosService;
  final ProveedorUbicacionCliente? proveedorUbicacion;
  final ConstructorMapaCercanos? constructorMapa;

  @override
  State<MapaCercanosPage> createState() => _MapaCercanosPageState();
}

class _MapaCercanosPageState extends State<MapaCercanosPage> {
  late final NegociosService _service =
      widget.negociosService ?? NegociosService();
  late final ProveedorUbicacionCliente _ubicacion =
      widget.proveedorUbicacion ?? UbicacionCliente().obtener;
  final DraggableScrollableController _hojaController =
      DraggableScrollableController();
  final Map<String, GlobalKey> _clavesTarjetas = {};

  bool _cargando = true;
  bool _error = false;
  // Posición efímera solo en memoria mientras esta pantalla está abierta.
  PosicionCliente? _posicion;
  List<NegocioCercano> _negocios = const [];
  String? _seleccionadoId;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _hojaController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = false;
      _posicion = null;
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
        _negocios = const [];
        _clavesTarjetas.clear();
        _cargando = false;
      });
      return;
    }
    try {
      final negocios = await _service.obtenerCercanos(
        lat: posicion.lat,
        lng: posicion.lng,
      );
      if (!mounted) return;
      setState(() {
        _posicion = posicion;
        _negocios = negocios;
        _clavesTarjetas
          ..clear()
          ..addEntries(negocios.map((n) => MapEntry(n.negocio.id, GlobalKey())));
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _posicion = null;
        _cargando = false;
      });
    }
  }

  void _alSeleccionarPin(String negocioId) {
    setState(() => _seleccionadoId = negocioId);
    if (_hojaController.isAttached && _hojaController.size < 0.5) {
      unawaited(
        _hojaController.animateTo(
          0.55,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contexto = _clavesTarjetas[negocioId]?.currentContext;
      if (contexto == null) return;
      Scrollable.ensureVisible(
        contexto,
        duration: const Duration(milliseconds: 250),
        alignment: 0.2,
        curve: Curves.easeOut,
      );
    });
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(MensajesNegocios.cercaDeTi),
        backgroundColor: Colors.white,
        foregroundColor: _texto,
        surfaceTintColor: Colors.transparent,
      ),
      body: _contenido(context),
    );
  }

  Widget _contenido(BuildContext context) {
    if (_cargando) return const EstadoCargando();
    if (_error) {
      return EstadoError(
        mensaje: MensajesNegocios.errorCercanos,
        onReintentar: _cargar,
      );
    }
    final posicion = _posicion;
    if (posicion == null || _negocios.isEmpty) {
      return const EstadoVacio(
        icono: Icons.location_off_outlined,
        mensaje: MensajesNegocios.sinCercanos,
      );
    }

    final pines = _pines;
    final datosMapa = DatosMapaCercanos(
      posicionCliente: posicion,
      pines: pines,
      seleccionadoId: _seleccionadoId,
      zoomInicial: calcularZoomInicial(
        posicion,
        pines.map((pin) => pin.ubicacion),
      ),
      onSeleccionarPin: _alSeleccionarPin,
    );

    final constructorMapa = widget.constructorMapa ?? _construirGoogleMap;

    return Stack(
      children: [
        Positioned.fill(child: constructorMapa(context, datosMapa)),
        DraggableScrollableSheet(
          controller: _hojaController,
          initialChildSize: 0.36,
          minChildSize: 0.22,
          maxChildSize: 0.82,
          snap: true,
          snapSizes: const [0.36, 0.55, 0.82],
          builder: (context, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(Radios.l),
              ),
              border: Border(top: BorderSide(color: _borde)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                _margen,
                Espacios.s,
                _margen,
                Espacios.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ExcludeSemantics(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: Espacios.m),
                        decoration: BoxDecoration(
                          color: _agarradera,
                          borderRadius: BorderRadius.circular(Radios.s),
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    header: true,
                    child: Text(
                      MensajesNegocios.lugaresCercanos(_negocios.length),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _texto,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: Espacios.m),
                  for (final (indice, cercano) in _negocios.indexed) ...[
                    if (indice > 0) const SizedBox(height: Espacios.m),
                    _ElementoListaMapa(
                      key: _clavesTarjetas[cercano.negocio.id],
                      cercano: cercano,
                      seleccionado: cercano.negocio.id == _seleccionadoId,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ElementoListaMapa extends StatelessWidget {
  const _ElementoListaMapa({
    super.key,
    required this.cercano,
    required this.seleccionado,
  });

  final NegocioCercano cercano;
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    final tarjeta = TarjetaNegocio(
      negocio: cercano.negocio,
      categoria: MensajesNegocios.distancia(cercano.distanciaKm),
    );
    return Semantics(
      selected: seleccionado,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(seleccionado ? 2 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radios.l + 2),
          border: seleccionado
              ? Border.all(color: ColoresServia.morado, width: 2)
              : null,
        ),
        child: tarjeta,
      ),
    );
  }
}

typedef _ClaveIconoPin = ({String etiqueta, bool seleccionado, double escala});

/// Implementación real con el SDK de Google Maps (`google_maps_flutter`).
@visibleForTesting
class VistaGoogleMap extends StatefulWidget {
  const VistaGoogleMap({
    super.key,
    required this.datos,
    this.generadorIconoPin = crearMarcadorDistancia,
    this.generadorIconoCliente = crearMarcadorCliente,
    this.constructorMapaNativo,
  });

  final DatosMapaCercanos datos;
  final GeneradorIconoPinMapa generadorIconoPin;
  final GeneradorIconoClienteMapa generadorIconoCliente;
  final ConstructorMapaNativo? constructorMapaNativo;

  @override
  State<VistaGoogleMap> createState() => VistaGoogleMapState();
}

@visibleForTesting
class VistaGoogleMapState extends State<VistaGoogleMap> {
  final Map<_ClaveIconoPin, BitmapDescriptor> _iconos = {};
  final Map<_ClaveIconoPin, Future<BitmapDescriptor>> _enCurso = {};
  BitmapDescriptor? _iconoCliente;
  Future<BitmapDescriptor>? _clienteEnCurso;
  GoogleMapController? _controller;
  double? _escala;
  int _generacion = 0;
  bool _desechado = false;

  @visibleForTesting
  int get entradasCacheParaPruebas =>
      _iconos.length +
      _enCurso.length +
      (_iconoCliente == null ? 0 : 1) +
      (_clienteEnCurso == null ? 0 : 1);

  double _normalizarEscala(double ratio) =>
      ratio.isFinite ? ratio.clamp(1.0, 4.0) : 1.0;

  void _limpiarCacheIconos() {
    _iconos.clear();
    _enCurso.clear();
    _iconoCliente = null;
    _clienteEnCurso = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final escala = _normalizarEscala(MediaQuery.devicePixelRatioOf(context));
    if (_escala != escala) {
      _escala = escala;
      _generacion++;
      _limpiarCacheIconos();
      _cargarIconos(escala);
    }
  }

  @override
  void didUpdateWidget(covariant VistaGoogleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final escala =
        _escala ?? _normalizarEscala(MediaQuery.devicePixelRatioOf(context));
    _cargarIconos(escala);
    final nuevoId = widget.datos.seleccionadoId;
    if (nuevoId != null && nuevoId != oldWidget.datos.seleccionadoId) {
      for (final pin in widget.datos.pines) {
        if (pin.id == nuevoId) {
          _controller?.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(pin.ubicacion.lat, pin.ubicacion.lng),
            ),
          );
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _desechado = true;
    _generacion++;
    _limpiarCacheIconos();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  _ClaveIconoPin _claveIcono(String etiqueta, bool seleccionado, double escala) =>
      (etiqueta: etiqueta, seleccionado: seleccionado, escala: escala);

  void _podarCache(double escala, Set<String> etiquetasActivas) {
    _iconos.removeWhere(
      (clave, _) =>
          clave.escala != escala || !etiquetasActivas.contains(clave.etiqueta),
    );
  }

  void _cargarIconos(double escala) {
    final generacion = _generacion;
    final etiquetasActivas = {
      for (final pin in widget.datos.pines) pin.etiqueta,
    };
    _podarCache(escala, etiquetasActivas);

    if (_iconoCliente == null && _clienteEnCurso == null) {
      final futuro = widget.generadorIconoCliente(pixelRatio: escala);
      _clienteEnCurso = futuro;
      unawaited(
        futuro.then(
          (icono) {
            if (_generacion == generacion) _clienteEnCurso = null;
            if (_desechado || !mounted || _generacion != generacion) return;
            _iconoCliente = icono;
            setState(() {});
          },
          onError: (Object _) {
            if (_generacion == generacion) _clienteEnCurso = null;
          },
        ),
      );
    }

    // Primero cargamos la variante visible actual de cada pin y en seguida
    // precalculamos la variante alterna para que tocar un pin no parpadee.
    for (final pin in widget.datos.pines) {
      _solicitarIconoPin(
        _claveIcono(pin.etiqueta, pin.seleccionado, escala),
        generacion,
      );
    }
    for (final pin in widget.datos.pines) {
      _solicitarIconoPin(
        _claveIcono(pin.etiqueta, !pin.seleccionado, escala),
        generacion,
      );
    }
  }

  void _solicitarIconoPin(_ClaveIconoPin clave, int generacion) {
    if (_iconos.containsKey(clave) || _enCurso.containsKey(clave)) return;
    final futuro = widget.generadorIconoPin(
      etiqueta: clave.etiqueta,
      seleccionado: clave.seleccionado,
      pixelRatio: clave.escala,
    );
    _enCurso[clave] = futuro;
    unawaited(
      futuro.then(
        (icono) {
          if (_generacion == generacion) _enCurso.remove(clave);
          if (_desechado || !mounted || _generacion != generacion) return;
          final sigueActivo = widget.datos.pines.any(
            (pin) => pin.etiqueta == clave.etiqueta,
          );
          if (!sigueActivo) return;
          _iconos[clave] = icono;
          setState(() {});
        },
        onError: (Object _) {
          if (_generacion == generacion) _enCurso.remove(clave);
        },
      ),
    );
  }

  Set<Marker> _marcadores() {
    final pos = widget.datos.posicionCliente;
    final escala = _escala;
    final marcadores = <Marker>{
      if (_iconoCliente case final iconoCliente?)
        Marker(
          markerId: const MarkerId('cliente'),
          position: LatLng(pos.lat, pos.lng),
          icon: iconoCliente,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
          consumeTapEvents: true,
          infoWindow: const InfoWindow(title: MensajesNegocios.tuUbicacion),
        ),
    };
    if (escala == null) return marcadores;
    for (final pin in widget.datos.pines) {
      final icono =
          _iconos[_claveIcono(pin.etiqueta, pin.seleccionado, escala)] ??
          _iconos[_claveIcono(pin.etiqueta, !pin.seleccionado, escala)];
      if (icono == null) continue;
      marcadores.add(
        Marker(
          markerId: MarkerId('negocio-${pin.id}'),
          position: LatLng(pin.ubicacion.lat, pin.ubicacion.lng),
          icon: icono,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: pin.seleccionado ? 3 : 2,
          consumeTapEvents: true,
          infoWindow: InfoWindow(title: pin.descripcionSemantica),
          onTap: () => widget.datos.onSeleccionarPin(pin.id),
        ),
      );
    }
    return marcadores;
  }

  Widget _construirMapaPorOmision({
    required CameraPosition camaraInicial,
    required Set<Marker> marcadores,
    required EdgeInsets padding,
    required MapCreatedCallback onMapCreated,
  }) {
    return GoogleMap(
      initialCameraPosition: camaraInicial,
      markers: marcadores,
      // Solo usamos la lectura puntual en memoria de `ubicacion_cliente.dart`.
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      padding: padding,
      onMapCreated: onMapCreated,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.datos.posicionCliente;
    final camaraInicial = CameraPosition(
      target: LatLng(pos.lat, pos.lng),
      zoom: widget.datos.zoomInicial,
    );
    final padding = EdgeInsets.only(
      bottom: MediaQuery.sizeOf(context).height * 0.36,
    );
    final constructor = widget.constructorMapaNativo ?? _construirMapaPorOmision;
    return constructor(
      camaraInicial: camaraInicial,
      marcadores: _marcadores(),
      padding: padding,
      onMapCreated: (controller) {
        if (_desechado) {
          controller.dispose();
          return;
        }
        _controller = controller;
      },
    );
  }
}
