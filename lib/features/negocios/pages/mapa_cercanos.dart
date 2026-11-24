import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/tokens.dart';
import '../data/negocio_cercano.dart';
import '../data/ubicacion_cliente.dart';
import '../data/ubicacion_negocio.dart';
import '../mensajes.dart';
import 'marcador_mapa.dart';

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
    this.padding = EdgeInsets.zero,
    this.onTocarMapa,
  });

  final PosicionCliente posicionCliente;
  final List<PinNegocioMapa> pines;
  final String? seleccionadoId;
  final double zoomInicial;
  final ValueChanged<String> onSeleccionarPin;

  /// Lo que tapan la hoja, la tarjeta flotante y los iconos superiores: el
  /// mapa centra la cámara en el resto para no esconder los pines.
  final EdgeInsets padding;

  /// Toque en el mapa fuera de los pines (cierra la tarjeta flotante).
  final VoidCallback? onTocarMapa;
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
      required ArgumentCallback<LatLng> onTap,
    });

/// Mapa real de Google por omisión; las pruebas inyectan uno falso.
Widget construirMapaCercanos(BuildContext context, DatosMapaCercanos datos) =>
    VistaGoogleMap(datos: datos);

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
    if (widget.datos.padding != oldWidget.datos.padding) {
      // La hoja o la tarjeta cambiaron de alto: reencuadra en lo visible.
      _reencuadrar();
      return;
    }
    final nuevoId = widget.datos.seleccionadoId;
    if (nuevoId != null && nuevoId != oldWidget.datos.seleccionadoId) {
      final pin = _pinSeleccionado();
      if (pin != null) {
        _animar(
          CameraUpdate.newLatLng(LatLng(pin.ubicacion.lat, pin.ubicacion.lng)),
        );
      }
    }
  }

  PinNegocioMapa? _pinSeleccionado() {
    for (final pin in widget.datos.pines) {
      if (pin.id == widget.datos.seleccionadoId) return pin;
    }
    return null;
  }

  void _animar(CameraUpdate actualizacion) {
    final controller = _controller;
    if (controller == null) return;
    // Si el mapa aún no tiene tamaño el SDK rechaza el encuadre; se ignora.
    unawaited(
      controller.animateCamera(actualizacion).catchError((Object _) {}),
    );
  }

  /// Centra el pin seleccionado o encuadra al cliente con todos los pines.
  void _reencuadrar() {
    final datos = widget.datos;
    final seleccionado = _pinSeleccionado();
    if (seleccionado != null) {
      _animar(
        CameraUpdate.newLatLng(
          LatLng(seleccionado.ubicacion.lat, seleccionado.ubicacion.lng),
        ),
      );
      return;
    }
    final cliente = datos.posicionCliente;
    var sur = cliente.lat, norte = cliente.lat;
    var oeste = cliente.lng, este = cliente.lng;
    for (final pin in datos.pines) {
      sur = math.min(sur, pin.ubicacion.lat);
      norte = math.max(norte, pin.ubicacion.lat);
      oeste = math.min(oeste, pin.ubicacion.lng);
      este = math.max(este, pin.ubicacion.lng);
    }
    if (datos.pines.isEmpty) {
      _animar(CameraUpdate.newLatLng(LatLng(cliente.lat, cliente.lng)));
      return;
    }
    _animar(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(sur, oeste),
          northeast: LatLng(norte, este),
        ),
        Espacios.xxxl,
      ),
    );
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

  _ClaveIconoPin _claveIcono(
    String etiqueta,
    bool seleccionado,
    double escala,
  ) => (etiqueta: etiqueta, seleccionado: seleccionado, escala: escala);

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
    required ArgumentCallback<LatLng> onTap,
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
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.datos.posicionCliente;
    final camaraInicial = CameraPosition(
      target: LatLng(pos.lat, pos.lng),
      zoom: widget.datos.zoomInicial,
    );
    final constructor =
        widget.constructorMapaNativo ?? _construirMapaPorOmision;
    return constructor(
      camaraInicial: camaraInicial,
      marcadores: _marcadores(),
      padding: widget.datos.padding,
      onTap: (_) => widget.datos.onTocarMapa?.call(),
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
