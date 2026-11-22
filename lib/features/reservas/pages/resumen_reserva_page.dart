import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/perfil.dart';
import '../../auth/data/perfil_service.dart';
import '../../negocios/data/servicio.dart';
import '../../negocios/formatos.dart';
import '../data/reservas_service.dart';
import '../fechas_reserva.dart';
import '../mensajes.dart';
import '../resultado_reserva.dart';
import 'confirmacion_reserva_page.dart';

/// Resumen previo al envío de la solicitud (MVP-18).
class ResumenReservaPage extends StatefulWidget {
  const ResumenReservaPage({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    required this.servicio,
    required this.fecha,
    required this.hora,
    this.authService,
    this.perfilService,
    this.reservasService,
    this.ahora = DateTime.now,
  });

  final String negocioId;
  final String negocioNombre;
  final Servicio servicio;

  /// `AAAA-MM-DD` y `HH:mm` en la hora del negocio (America/Mexico_City).
  final String fecha;
  final String hora;
  final AuthService? authService;
  final PerfilService? perfilService;
  final ReservasService? reservasService;
  final DateTime Function() ahora;

  @override
  State<ResumenReservaPage> createState() => _ResumenReservaPageState();
}

class _ResumenReservaPageState extends State<ResumenReservaPage> {
  late final AuthService _auth;
  late final PerfilService _perfilService;
  late final ReservasService _reservas;
  final _observaciones = TextEditingController();

  Perfil? _perfil;
  Object? _errorContacto;
  String? _errorEnvio;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.authService ?? AuthService();
    _perfilService = widget.perfilService ?? PerfilService();
    _reservas = widget.reservasService ?? ReservasService();
    _cargarContacto();
  }

  @override
  void dispose() {
    _observaciones.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final token = await _auth.usuarioActual?.getIdToken();
    if (token == null) throw const ApiException(401, 'Sin sesión.');
    return token;
  }

  Future<void> _cargarContacto() async {
    setState(() {
      _perfil = null;
      _errorContacto = null;
    });
    try {
      final perfil = await _perfilService.obtenerYo(await _token());
      if (!mounted) return;
      setState(() => _perfil = perfil);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorContacto = error);
    }
  }

  bool get _puedeEnviar => !_enviando && _perfil != null && _perfil!.esCliente;

  Future<void> _enviar() async {
    if (!_puedeEnviar) return;
    setState(() {
      _enviando = true;
      _errorEnvio = null;
    });
    try {
      final reserva = await _reservas.crear(
        await _token(),
        SolicitudReserva(
          negocioId: widget.negocioId,
          servicioId: widget.servicio.id,
          inicio: inicioIsoConZona(widget.fecha, widget.hora),
          observaciones: _observaciones.text,
        ),
      );
      if (!mounted) return;
      Navigator.pushReplacement<ResultadoReserva, ResultadoReserva>(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmacionReservaPage(
            reserva: reserva,
            negocioNombre: widget.negocioNombre,
            servicioNombre: widget.servicio.nombre,
            fecha: widget.fecha,
            hora: widget.hora,
          ),
        ),
        result: ResultadoReserva.enviada,
      );
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 409) {
        Navigator.pop(context, ResultadoReserva.horarioOcupado);
        return;
      }
      if (error is ApiException && error.statusCode == 401) {
        // El token ya no sirve: se cierra la sesión para volver a pedirla.
        await _auth.cerrarSesion();
        if (!mounted) return;
      }
      setState(() {
        _enviando = false;
        _errorEnvio = MensajesReservas.mensajeDeEnvio(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inicio = inicioDeCita(widget.fecha, widget.hora);
    final sinCancelacion = citaEnMenosDe24Horas(inicio, widget.ahora());

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Cabecera minimalista sin AppBar pesado
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed:
                        _enviando ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF111827),
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      MensajesReservas.titulo,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),

            // Contenido desplazable
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, Espacios.xxl),
                children: [
                  // 1. Tarjeta principal con los datos de la reserva
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Encabezado del negocio y servicio
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Color(0xFF7C3AED),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.negocioNombre,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.servicio.nombre,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                        ),

                        _Dato(
                          MensajesReservas.fecha,
                          formatearFechaLarga(widget.fecha),
                        ),
                        _Dato(
                          MensajesReservas.hora,
                          widget.hora,
                          tabular: true,
                        ),
                        _Dato(
                          MensajesReservas.duracion,
                          formatearDuracion(widget.servicio.duracionMin),
                        ),

                        const Padding(
                          padding: EdgeInsets.only(top: 4, bottom: 14),
                          child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                        ),

                        // Fila destacada de precio total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              MensajesReservas.precioTotal,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                            Text(
                              formatearPrecio(widget.servicio.precio),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Tarjeta de datos de contacto del cliente
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                    ),
                    child: _contacto(context),
                  ),

                  const SizedBox(height: 20),

                  // 3. Campo de observaciones con estilo limpio redondeado
                  const Text(
                    MensajesReservas.observaciones,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _observaciones,
                    enabled: !_enviando,
                    maxLength: MensajesReservas.maxObservaciones,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                    decoration: InputDecoration(
                      hintText: MensajesReservas.observacionesAyuda,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF0F0F0F),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 4. Avisos informativos y de cancelación
                  const _BannerAvisoResumen(
                    icono: Icons.access_time_rounded,
                    colorIcono: Color(0xFF7C3AED),
                    fondo: Color(0xFFF7F7F8),
                    borde: Color(0xFFE5E7EB),
                    colorTexto: Color(0xFF374151),
                    texto: MensajesReservas.avisoDosHoras,
                  ),

                  if (sinCancelacion) ...[
                    const SizedBox(height: 10),
                    const _BannerAvisoResumen(
                      icono: Icons.warning_amber_rounded,
                      colorIcono: Color(0xFFB45309),
                      fondo: Color(0xFFFEF3C7),
                      borde: Color(0xFFFDE68A),
                      colorTexto: Color(0xFF92400E),
                      texto: MensajesReservas.sinCancelacion,
                    ),
                  ],

                  if (_errorEnvio != null) ...[
                    const SizedBox(height: 10),
                    _BannerAvisoResumen(
                      icono: Icons.error_outline_rounded,
                      colorIcono: const Color(0xFFB91C1C),
                      fondo: const Color(0xFFFEE2E2),
                      borde: const Color(0xFFFECACA),
                      colorTexto: const Color(0xFF991B1B),
                      texto: _errorEnvio!,
                    ),
                  ],
                ],
              ),
            ),

            // Barra inferior fija con precio total y botón píldora negro
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF3F4F6), width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatearPrecio(widget.servicio.precio),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                                letterSpacing: -0.3,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatearDuracion(widget.servicio.duracionMin),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _puedeEnviar ? _enviar : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F0F0F),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
                            disabledForegroundColor: const Color(0xFF9CA3AF),
                            elevation: 0,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(
                            _enviando
                                ? MensajesReservas.enviando
                                : MensajesReservas.enviar,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contacto(BuildContext context) {
    const titulo = Text(
      MensajesReservas.contacto,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );

    final error = _errorContacto;
    if (error != null) {
      final sesion = error is ApiException && error.statusCode == 401;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.person_off_outlined,
            size: 20,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titulo,
                const SizedBox(height: 4),
                Text(
                  sesion
                      ? MensajesReservas.sesionVencida
                      : MensajesReservas.mensajeDeEnvio(error),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          if (!sesion)
            TextButton(
              onPressed: _cargarContacto,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0F0F0F),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('Reintentar'),
            ),
        ],
      );
    }

    final perfil = _perfil;
    if (perfil == null) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titulo,
                SizedBox(height: 2),
                Text(
                  MensajesReservas.cargandoContacto,
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (!perfil.esCliente) {
      return const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: Color(0xFFB45309),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titulo,
                SizedBox(height: 4),
                Text(
                  MensajesReservas.soloClientes,
                  style: TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final telefono = perfil.telefono;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 20,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titulo,
              const SizedBox(height: 6),
              Text(
                perfil.nombre,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                perfil.correo,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
              if (telefono != null && telefono.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  telefono,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
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

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor, {this.tabular = false});

  final String etiqueta;
  final String valor;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              etiqueta,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              valor,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
                fontFeatures:
                    tabular ? const [FontFeature.tabularFigures()] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerAvisoResumen extends StatelessWidget {
  const _BannerAvisoResumen({
    required this.icono,
    required this.colorIcono,
    required this.fondo,
    required this.borde,
    required this.colorTexto,
    required this.texto,
  });

  final IconData icono;
  final Color colorIcono;
  final Color fondo;
  final Color borde;
  final Color colorTexto;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borde, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 19, color: colorIcono),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colorTexto,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}