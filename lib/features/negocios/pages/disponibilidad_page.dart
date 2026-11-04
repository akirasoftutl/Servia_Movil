import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../core/theme/colores_servia.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
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

  /// Estado de toda la pantalla (cargando, error o sin días), si aplica.
  Widget? _estadoGeneral() {
    if (_errorDias != null) return _error(_errorDias!, _cargarDias);
    final dias = _dias;
    if (dias == null) return const EstadoCargando();
    if (dias.isEmpty) return _sinDisponibilidad();
    return null;
  }

  Widget _contenido(BuildContext context) {
    final dias = _dias!;
    final horas = _horasVigentes;
    final tema = Theme.of(context);
    final c = tema.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.aviso != null) ...[
          Aviso(texto: widget.aviso!, tipo: TipoAviso.advertencia),
          const SizedBox(height: Espacios.l),
        ],
        Text('Elige una fecha', style: tema.textTheme.titleLarge),
        const SizedBox(height: Espacios.xs),
        Row(
          children: [
            Icon(Icons.public, size: 16, color: c.onSurfaceVariant),
            const SizedBox(width: Espacios.xs + 2),
            Flexible(
              child: Text(
                'Horarios de America/Mexico_City',
                style: tema.textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: Espacios.m),
        Card(
          child: CalendarDatePicker(
            key: ValueKey(dias),
            initialDate: null,
            currentDate: dias.first.calendario,
            firstDate: dias.first.calendario,
            lastDate: dias.last.calendario,
            selectableDayPredicate: (fecha) => dias.any(
              (dia) => dia.fecha == fechaIso(fecha) && dia.disponible,
            ),
            onDateChanged: (fecha) => _cargarHoras(fechaIso(fecha)),
          ),
        ),
        if (!dias.any((dia) => dia.disponible))
          _sinDisponibilidad(compacto: true),
        if (_fecha != null) ...[
          const SizedBox(height: Espacios.xl),
          Text('Horarios del $_fecha', style: tema.textTheme.titleMedium),
          const SizedBox(height: Espacios.m),
          if (_errorHoras != null)
            _error(_errorHoras!, () => _cargarHoras(_fecha!), compacto: true)
          else if (_horas == null)
            const EstadoCargando(compacto: true)
          else ...[
            if (!horas.any((hora) => hora.disponible))
              _sinDisponibilidad(compacto: true),
            if (horas.isNotEmpty)
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < horas.length; i++) ...[
                      if (i > 0) const Divider(),
                      _FilaHora(
                        hora: horas[i],
                        onElegir: () => _seleccionar(horas[i]),
                      ),
                    ],
                  ],
                ),
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
        body:
            _estadoGeneral() ??
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Espacios.l,
                Espacios.s,
                Espacios.l,
                Espacios.xxl,
              ),
              child: _contenido(context),
            ),
      ),
    ),
  );
}

class _FilaHora extends StatelessWidget {
  const _FilaHora({required this.hora, required this.onElegir});
  final HoraDisponibilidad hora;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    final s = ColoresSemanticos.de(context);
    final textos = Theme.of(context).textTheme;
    return ListTile(
      key: ValueKey('hora-${hora.hora}'),
      enabled: hora.disponible,
      title: Text(
        hora.hora,
        style: textos.titleMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      subtitle: Text(
        hora.disponible ? 'Disponible' : 'Ocupado',
        style: textos.bodySmall?.copyWith(
          color: hora.disponible ? s.exito : null,
        ),
      ),
      leading: Icon(
        hora.disponible ? Icons.schedule : Icons.block,
        color: hora.disponible ? ColoresServia.marca : null,
      ),
      onTap: hora.disponible ? onElegir : null,
    );
  }
}
