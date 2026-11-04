import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../core/widgets/estados.dart';
import '../data/disponibilidad.dart';
import '../data/disponibilidad_service.dart';
import '../mensajes.dart';

class DisponibilidadPage extends StatefulWidget {
  const DisponibilidadPage({
    super.key,
    required this.negocioId,
    required this.servicioId,
    this.service,
    this.ahora = DateTime.now,
    this.aviso,
  });
  final String negocioId;
  final String servicioId;
  final DisponibilidadService? service;
  final DateTime Function() ahora;

  /// Mensaje al volver a elegir horario (por ejemplo, el horario se ocupó).
  final String? aviso;

  @override
  State<DisponibilidadPage> createState() => _DisponibilidadPageState();
}

class _DisponibilidadPageState extends State<DisponibilidadPage>
    with WidgetsBindingObserver {
  late final DisponibilidadService _service;
  List<DiaDisponibilidad>? _dias;
  List<HoraDisponibilidad>? _horas;
  String? _fecha;
  Object? _errorDias;
  Object? _errorHoras;
  int _consulta = 0;
  Timer? _vencimiento;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = widget.service ?? DisponibilidadService();
    _cargarDias();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _vencimiento?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cargarDias();
  }

  Future<void> _cargarDias() async {
    _consulta++;
    _vencimiento?.cancel();
    setState(() {
      _dias = null;
      _horas = null;
      _fecha = null;
      _errorDias = null;
      _errorHoras = null;
    });
    final consulta = _consulta;
    try {
      final dias = await _service.obtenerDias(
        widget.negocioId,
        widget.servicioId,
      );
      if (!mounted || consulta != _consulta) return;
      setState(() => _dias = dias);
    } catch (error) {
      if (!mounted || consulta != _consulta) return;
      setState(() => _errorDias = error);
    }
  }

  Future<void> _cargarHoras(String fecha) async {
    final consulta = ++_consulta;
    _vencimiento?.cancel();
    setState(() {
      _fecha = fecha;
      _horas = null;
      _errorHoras = null;
    });
    try {
      final horas = await _service.obtenerHoras(
        widget.negocioId,
        widget.servicioId,
        fecha,
      );
      if (!mounted || consulta != _consulta) return;
      setState(() => _horas = horas);
      _programarVencimiento();
    } catch (error) {
      if (!mounted || consulta != _consulta) return;
      setState(() => _errorHoras = error);
    }
  }

  List<HoraDisponibilidad> get _horasVigentes => (_horas ?? [])
      .where((hora) => hora.inicio(_fecha!).isAfter(widget.ahora()))
      .toList();

  // RN-39: retirar también las horas que vencen con la pantalla abierta.
  void _programarVencimiento() {
    final horas = _horasVigentes;
    if (horas.isEmpty) return;
    final siguiente = horas
        .map((h) => h.inicio(_fecha!))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    _vencimiento = Timer(siguiente.difference(widget.ahora()), () {
      if (!mounted) return;
      setState(() {});
      _programarVencimiento();
    });
  }

  void _seleccionar(HoraDisponibilidad hora) {
    // MVP-18 deberá revalidar disponibilidad en la API antes de reservar.
    if (!hora.disponible || !hora.inicio(_fecha!).isAfter(widget.ahora())) {
      return;
    }
    Navigator.pop(
      context,
      SeleccionDisponibilidad(
        negocioId: widget.negocioId,
        servicioId: widget.servicioId,
        fecha: _fecha!,
        hora: hora.hora,
      ),
    );
  }

  Widget _error(
    Object error,
    VoidCallback reintentar, {
    bool compacto = false,
  }) => EstadoError(
    compacto: compacto,
    mensaje: MensajesNegocios.mensajeDeError(error, esServicio: true),
    onReintentar: MensajesNegocios.puedeReintentar(error) ? reintentar : null,
  );

  Widget _sinDisponibilidad({bool compacto = false}) => EstadoVacio(
    compacto: compacto,
    icono: Icons.event_busy_outlined,
    mensaje: 'No hay disponibilidad en este momento',
  );

  Widget _contenido(BuildContext context) {
    if (_errorDias != null) return _error(_errorDias!, _cargarDias);
    final dias = _dias;
    if (dias == null) return const EstadoCargando();
    if (dias.isEmpty) return _sinDisponibilidad();
    final horas = _horasVigentes;
    return Column(
      children: [
        if (widget.aviso != null) Text(widget.aviso!),
        Text('Elige una fecha', style: Theme.of(context).textTheme.titleLarge),
        const Text('Horarios de America/Mexico_City'),
        CalendarDatePicker(
          key: ValueKey(dias),
          initialDate: null,
          currentDate: dias.first.calendario,
          firstDate: dias.first.calendario,
          lastDate: dias.last.calendario,
          selectableDayPredicate: (fecha) =>
              dias.any((dia) => dia.fecha == fechaIso(fecha) && dia.disponible),
          onDateChanged: (fecha) => _cargarHoras(fechaIso(fecha)),
        ),
        if (!dias.any((dia) => dia.disponible))
          _sinDisponibilidad(compacto: true),
        if (_fecha != null) ...[
          Text(
            'Horarios del $_fecha',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_errorHoras != null)
            _error(_errorHoras!, () => _cargarHoras(_fecha!), compacto: true)
          else if (_horas == null)
            const EstadoCargando(compacto: true)
          else ...[
            if (!horas.any((hora) => hora.disponible))
              _sinDisponibilidad(compacto: true),
            for (final hora in horas)
              ListTile(
                key: ValueKey('hora-${hora.hora}'),
                enabled: hora.disponible,
                title: Text(hora.hora),
                subtitle: Text(hora.disponible ? 'Disponible' : 'Ocupado'),
                onTap: hora.disponible ? () => _seleccionar(hora) : null,
              ),
          ],
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    locale: const Locale('es', 'MX'),
    delegates: GlobalMaterialLocalizations.delegates,
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Disponibilidad del servicio')),
        body: SingleChildScrollView(child: _contenido(context)),
      ),
    ),
  );
}
