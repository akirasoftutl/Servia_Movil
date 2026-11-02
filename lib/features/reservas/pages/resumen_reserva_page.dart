import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
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

  bool get _puedeEnviar =>
      !_enviando && _perfil != null && _perfil!.esCliente;

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
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text(MensajesReservas.titulo)),
      body: ListView(
        children: [
          _Dato(MensajesReservas.negocio, widget.negocioNombre),
          _Dato(MensajesReservas.servicio, widget.servicio.nombre),
          _Dato(MensajesReservas.fecha, formatearFechaLarga(widget.fecha)),
          _Dato(MensajesReservas.hora, widget.hora),
          _Dato(
            MensajesReservas.duracion,
            formatearDuracion(widget.servicio.duracionMin),
          ),
          _Dato(
            MensajesReservas.precioTotal,
            formatearPrecio(widget.servicio.precio),
          ),
          const Divider(),
          _contacto(context),
          const Divider(),
          ListTile(
            title: TextField(
              controller: _observaciones,
              enabled: !_enviando,
              maxLength: MensajesReservas.maxObservaciones,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: MensajesReservas.observaciones,
                hintText: MensajesReservas.observacionesAyuda,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.schedule),
            title: Text(MensajesReservas.avisoDosHoras),
          ),
          if (sinCancelacion)
            Card(
              color: esquema.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_outlined,
                  color: esquema.onErrorContainer,
                ),
                title: Text(
                  MensajesReservas.sinCancelacion,
                  style: TextStyle(color: esquema.onErrorContainer),
                ),
              ),
            ),
          if (_errorEnvio != null)
            Card(
              color: esquema.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.error_outline,
                  color: esquema.onErrorContainer,
                ),
                title: Semantics(
                  liveRegion: true,
                  child: Text(
                    _errorEnvio!,
                    style: TextStyle(color: esquema.onErrorContainer),
                  ),
                ),
              ),
            ),
          ListTile(
            title: FilledButton(
              onPressed: _puedeEnviar ? _enviar : null,
              child: Text(
                _enviando
                    ? MensajesReservas.enviando
                    : MensajesReservas.enviar,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contacto(BuildContext context) {
    final titulo = Text(
      MensajesReservas.contacto,
      style: Theme.of(context).textTheme.titleMedium,
    );
    final error = _errorContacto;
    if (error != null) {
      final sesion = error is ApiException && error.statusCode == 401;
      return ListTile(
        title: titulo,
        subtitle: Text(
          sesion
              ? MensajesReservas.sesionVencida
              : MensajesReservas.mensajeDeEnvio(error),
        ),
        trailing: sesion
            ? null
            : TextButton(
                onPressed: _cargarContacto,
                child: const Text('Reintentar'),
              ),
      );
    }
    final perfil = _perfil;
    if (perfil == null) {
      return ListTile(
        title: titulo,
        subtitle: const Text(MensajesReservas.cargandoContacto),
      );
    }
    if (!perfil.esCliente) {
      return ListTile(
        title: titulo,
        subtitle: const Text(MensajesReservas.soloClientes),
      );
    }
    final telefono = perfil.telefono;
    return ListTile(
      title: titulo,
      subtitle: Text(
        [
          perfil.nombre,
          perfil.correo,
          if (telefono != null && telefono.isNotEmpty) telefono,
        ].join('\n'),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) =>
      ListTile(title: Text(etiqueta), subtitle: Text(valor));
}
