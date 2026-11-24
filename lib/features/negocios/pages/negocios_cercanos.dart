import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/estados.dart';
import '../data/negocio_cercano.dart';
import '../data/negocios_service.dart';
import '../data/ubicacion_cliente.dart';
import '../mensajes.dart';
import 'mapa_cercanos_page.dart';
import 'tarjeta_negocio.dart';

// Márgenes literales de la lista del rediseño (`lista_negocios_page.dart`).
const _margen = 20.0;
const _separacion = 14.0;
const _texto = Color(0xFF111827);
const _bordeBoton = Color(0xFFD1D5DB);
const _estiloMensaje = TextStyle(fontSize: 14, color: Color(0xFF6B7280));

class NegociosCercanos extends StatefulWidget {
  const NegociosCercanos({
    super.key,
    this.service,
    this.proveedorUbicacion,
    this.constructorMapa,
  });
  final NegociosService? service;
  final ProveedorUbicacionCliente? proveedorUbicacion;
  final ConstructorMapaCercanos? constructorMapa;

  @override
  State<NegociosCercanos> createState() => _NegociosCercanosState();
}

class _NegociosCercanosState extends State<NegociosCercanos> {
  late final _service = widget.service ?? NegociosService();
  late final _ubicacion =
      widget.proveedorUbicacion ?? UbicacionCliente().obtener;
  bool _visible = false;
  bool _cargando = false;
  bool _error = false;
  List<NegocioCercano> _negocios = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    // Las coordenadas viven solo en esta consulta, tampoco se retienen para reintentar.
    PosicionCliente? posicion;
    try {
      posicion = await _ubicacion();
    } catch (_) {
      posicion = null;
    }
    if (!mounted) return;
    if (posicion == null) {
      setState(() {
        _visible = false;
        _cargando = false;
      });
      return;
    }
    setState(() => _visible = true);
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

  void _abrirMapa() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MapaCercanosPage(
          negociosService: _service,
          proveedorUbicacion: _ubicacion,
          constructorMapa: widget.constructorMapa,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final mostrarVerMapa = !_cargando && !_error && _negocios.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_margen, Espacios.l, _margen, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                MensajesNegocios.cercaDeTi,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _texto,
                  letterSpacing: -0.3,
                ),
              ),
              if (mostrarVerMapa) ...[
                const SizedBox(height: Espacios.xs),
                OutlinedButton.icon(
                  onPressed: _abrirMapa,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _texto,
                    side: const BorderSide(color: _bordeBoton),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(Medidas.tactil, Medidas.tactil),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text(
                    MensajesNegocios.verMapa,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_cargando)
          const EstadoCargando(compacto: true)
        else if (_error) ...[
          const SizedBox(height: Espacios.s),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: _margen),
            child: Text(MensajesNegocios.errorCercanos, style: _estiloMensaje),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(_margen, Espacios.s, _margen, 0),
            child: OutlinedButton(
              onPressed: _cargar,
              style: OutlinedButton.styleFrom(
                foregroundColor: _texto,
                side: const BorderSide(color: _bordeBoton),
                shape: const StadiumBorder(),
              ),
              child: const Text(
                MensajesNegocios.reintentar,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: Espacios.s),
        ] else if (_negocios.isEmpty) ...[
          const SizedBox(height: Espacios.s),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: _margen),
            child: Text(MensajesNegocios.sinCercanos, style: _estiloMensaje),
          ),
          const SizedBox(height: Espacios.s),
        ] else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(_margen, 12, _margen, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (indice, cercano) in _negocios.indexed) ...[
                  if (indice > 0) const SizedBox(width: _separacion),
                  SizedBox(
                    width: 300,
                    child: TarjetaNegocio(
                      negocio: cercano.negocio,
                      categoria: MensajesNegocios.distancia(
                        cercano.distanciaKm,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
