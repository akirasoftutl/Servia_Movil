import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
    this.cargarDias,
    this.cargarHoras,
  });

  final String negocioId;
  final String servicioId;
  final DisponibilidadService? service;
  final DateTime Function() ahora;

  /// Mensaje al volver a elegir horario (por ejemplo, el horario se ocupó).
  final String? aviso;

  /// Para reprogramar (T18): consultan la disponibilidad privada de la reserva
  /// (con el token del cliente) en lugar de la ruta pública del servicio.
  final Future<List<DiaDisponibilidad>> Function()? cargarDias;
  final Future<List<HoraDisponibilidad>> Function(String fecha)? cargarHoras;

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

  double _desplazamientoY = 0;
  bool _arrastrando = false;

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
      final dias =
          await widget.cargarDias?.call() ??
          await _service.obtenerDias(widget.negocioId, widget.servicioId);
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
      final horas =
          await widget.cargarHoras?.call(fecha) ??
          await _service.obtenerHoras(
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

  void _onVerticalDragStart(DragStartDetails details) {
    setState(() => _arrastrando = true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _desplazamientoY = (_desplazamientoY + details.delta.dy).clamp(0.0, 700.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocidad = details.primaryVelocity ?? 0;
    if (_desplazamientoY > 110 || velocidad > 650) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _arrastrando = false;
      _desplazamientoY = 0;
    });
  }

  Widget _error(
    Object error,
    VoidCallback reintentar, {
    bool compacto = false,
  }) =>
      EstadoError(
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
    final temaBase = Theme.of(context);

    Widget margen(List<Widget> hijos) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: hijos,
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        margen([
          const Text(
            'Disponibilidad del servicio',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              height: 1.18,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.public, size: 15, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Horarios de America/Mexico_City',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          if (widget.aviso != null) ...[
            const SizedBox(height: 16),
            Aviso(texto: widget.aviso!, tipo: TipoAviso.advertencia),
          ],
          const SizedBox(height: 20),
          const Text(
            'Elige una fecha',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
        ]),

        // El calendario va de borde a borde para que cada día mida >= 48 dp
        // de ancho aun en teléfonos de 360 dp.
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border.symmetric(
              horizontal: BorderSide(color: Color(0xFFE5E7EB), width: 1),
            ),
          ),
          child: Theme(
            data: temaBase.copyWith(
              colorScheme: temaBase.colorScheme.copyWith(
                primary: const Color(0xFF0F0F0F),
                onPrimary: Colors.white,
                surface: const Color(0xFFF9FAFB),
                onSurface: const Color(0xFF111827),
                onSurfaceVariant: const Color(0xFF6B7280),
              ),
              datePickerTheme: DatePickerThemeData(
                backgroundColor: const Color(0xFFF9FAFB),
                dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF0F0F0F);
                  }
                  return null;
                }),
                dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  if (states.contains(WidgetState.disabled)) {
                    return const Color(0xFFD1D5DB);
                  }
                  return const Color(0xFF111827);
                }),
                todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return const Color(0xFF7C3AED);
                }),
                todayBorder: const BorderSide(
                  color: Color(0xFF7C3AED),
                  width: 1.2,
                ),
              ),
            ),
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
        ),

        margen([
          if (!dias.any((dia) => dia.disponible)) ...[
            const SizedBox(height: 16),
            _sinDisponibilidad(compacto: true),
          ],
          if (_fecha != null) ...[
            const SizedBox(height: 24),
            Text(
              'Horarios del $_fecha',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),
            if (_errorHoras != null)
              _error(_errorHoras!, () => _cargarHoras(_fecha!), compacto: true)
            else if (_horas == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: EstadoCargando(compacto: true),
              )
            else ...[
              if (!horas.any((hora) => hora.disponible))
                _sinDisponibilidad(compacto: true),
              if (horas.isNotEmpty)
                Column(
                  children: [
                    for (var i = 0; i < horas.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _FilaHora(
                        hora: horas[i],
                        onElegir: () => _seleccionar(horas[i]),
                      ),
                    ],
                  ],
                ),
            ],
          ],
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      locale: const Locale('es', 'MX'),
      delegates: GlobalMaterialLocalizations.delegates,
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFFF3F4F6),
          body: SafeArea(
            bottom: false,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: _onVerticalDragStart,
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              child: AnimatedContainer(
                duration: _arrastrando
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(0, _desplazamientoY, 0),
                margin: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Contorno superior idéntico al detalle de servicio: manejador + botón 'X'
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 16, 8),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1D5DB),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.close,
                                color: Color(0xFF111827),
                                size: 26,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _estadoGeneral() ??
                          SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: const EdgeInsets.only(
                              top: 4,
                              bottom: Espacios.xxl,
                            ),
                            child: _contenido(context),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilaHora extends StatelessWidget {
  const _FilaHora({required this.hora, required this.onElegir});

  final HoraDisponibilidad hora;
  final VoidCallback onElegir;

  @override
  Widget build(BuildContext context) {
    final disponible = hora.disponible;

    return Material(
      key: ValueKey('hora-${hora.hora}'),
      color: disponible ? Colors.white : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: disponible ? onElegir : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: disponible
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFFF3F4F6),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                disponible
                    ? Icons.access_time_rounded
                    : Icons.block_rounded,
                size: 20,
                color: disponible
                    ? const Color(0xFF111827)
                    : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hora.hora,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: disponible
                        ? const Color(0xFF111827)
                        : const Color(0xFF9CA3AF),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (disponible)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Elegir',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Ocupado',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}