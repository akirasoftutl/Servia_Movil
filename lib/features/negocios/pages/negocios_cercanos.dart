import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../data/negocio_cercano.dart';
import '../data/negocios_service.dart';
import '../data/ubicacion_cliente.dart';
import '../mensajes.dart';
import 'tarjeta_negocio.dart';

// Márgenes literales de la lista del rediseño (`lista_negocios_page.dart`).
const _margen = 20.0;
const _separacion = 14.0;

class NegociosCercanos extends StatefulWidget {
  const NegociosCercanos({super.key, this.service, this.proveedorUbicacion});
  final NegociosService? service;
  final ProveedorUbicacionCliente? proveedorUbicacion;

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

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Espacios.l),
          child: Text(
            MensajesNegocios.cercaDeTi,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (_cargando)
          const Center(child: CircularProgressIndicator())
        else if (_error) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Espacios.l),
            child: Text(MensajesNegocios.errorCercanos),
          ),
          TextButton(
            onPressed: _cargar,
            child: const Text(MensajesNegocios.reintentar),
          ),
        ] else if (_negocios.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Espacios.l),
            child: Text(MensajesNegocios.sinCercanos),
          )
        else
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
