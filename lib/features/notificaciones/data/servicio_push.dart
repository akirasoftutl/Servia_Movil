import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../mensajes.dart';
import 'messaging_client.dart';
import 'notificaciones_service.dart';

///Coordina FCM con la API de avisos.
///
/// * Pide permiso y registra el token cuando se confirma una sesión de cliente.
/// * Reenvía el token en `onTokenRefresh`.
/// * Da de baja el token antes de cerrar sesión.
/// * Mantiene el número de no leídos y atiende los mensajes (primer plano,
///   segundo plano y app cerrada).
class ServicioPush {
  ServicioPush({
    MessagingClient? messaging,
    NotificacionesService? notificaciones,
    GlobalKey<NavigatorState>? navigatorKey,
  })  : _messaging = messaging ?? MessagingClient(),
        _notificaciones = notificaciones ?? NotificacionesService(),
        navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

  /// Instancia compartida por `main`, `AuthGate`, el inicio y el detalle.
  static final ServicioPush instancia = ServicioPush();

  final MessagingClient _messaging;
  final NotificacionesService _notificaciones;

  /// Llave usada por [navigatorKey] en `MaterialApp` para navegar aunque el
  /// mensaje llegue con la app cerrada o en segundo plano.
  final GlobalKey<NavigatorState> navigatorKey;

  /// Lo observa la campana de `HomePage`. Se siembra con `GET /notificaciones`
  /// y se ajusta cuando llega un push o se abre un aviso.
  final ValueNotifier<int> noLeidas = ValueNotifier<int>(0);

  final List<StreamSubscription<dynamic>> _suscripciones = [];
  bool _configurado = false;
  bool _registrando = false;
  bool _permisoConcedido = false;
  bool _registrado = false;
  String? _tokenApi;
  String? _tokenFcm;
  RemoteMessage? _pendiente;

  /// Instala los listeners. Llamarlo una sola vez, desde `main`.
  void configurar() {
    if (_configurado) return;
    _configurado = true;
    try {
      _suscripciones.add(_messaging.onMessage.listen(_alRecibirEnPrimerPlano));
      _suscripciones.add(
        _messaging.onMessageOpenedApp.listen(_alAbrirDesdePush),
      );
      _suscripciones.add(
        _messaging.onTokenRefresh.listen(
          (token) => unawaited(_alRenovarToken(token)),
        ),
      );
    } catch (_) {
      // Sin plugin (tests) no hay streams: la lista de avisos sigue activa.
    }
  }

  /// `getInitialMessage` se consulta aparte porque la navegación debe esperar
  /// a que [AuthGate] confirme la sesión del cliente.
  Future<void> cargarMensajeInicial() async {
    try {
      final mensaje = await _messaging.getInitialMessage();
      if (mensaje != null) _pendiente ??= mensaje;
    } catch (_) {
      // Sin plugin (tests) o sin Firebase: los avisos de la lista siguen
      // funcionando.
    }
  }

  /// Pide permiso (Android 13+), obtiene el token y lo envía a la API.
  /// Si el usuario lo niega no hace nada: la lista de avisos sigue disponible.
  Future<void> registrar(String token, {bool forzar = false}) async {
    if (_registrando) return;
    _registrando = true;
    _tokenApi = token;
    try {
      if (_registrado && !forzar) return;

      final permisos = await _messaging.requestPermission();
      _permisoConcedido =
          permisos.authorizationStatus == AuthorizationStatus.authorized ||
          permisos.authorizationStatus == AuthorizationStatus.provisional;
      if (!_permisoConcedido) return;

      final tokenFcm = await _messaging.getToken();
      if (tokenFcm == null || tokenFcm.isEmpty) return;

      _tokenFcm = tokenFcm;
      await _notificaciones.registrarToken(token, tokenFcm);
      _registrado = true;
    } catch (_) {
      // Un fallo de red o del plugin no debe impedir el acceso a la app.
    } finally {
      _registrando = false;
    }
  }

  /// Se llama antes de `FirebaseAuth.signOut()`.
  Future<void> desactivar(String token) async {
    _tokenApi = null;
    var tokenFcm = _tokenFcm;
    if (tokenFcm == null) {
      try {
        tokenFcm = await _messaging.getToken();
      } catch (_) {
        tokenFcm = null;
      }
    }
    try {
      if (tokenFcm != null && tokenFcm.isNotEmpty) {
        await _notificaciones.desactivarToken(token, tokenFcm);
      }
    } catch (_) {
      // Se cierra la sesión aunque la API no esté disponible.
    } finally {
      _limpiarSesion();
    }
  }

  void sincronizarNoLeidas(int cantidad) {
    noLeidas.value = cantidad < 0 ? 0 : cantidad;
  }

  void marcarLeidaLocal() {
    if (noLeidas.value > 0) noLeidas.value--;
  }

  /// Atiende el mensaje que abrió la app desde cerrada, una vez que ya hay
  /// sesión y, por tanto, token de la API para marcarlo como leído.
  Future<void> procesarMensajePendiente(String token) async {
    final mensaje = _pendiente;
    if (mensaje == null) return;
    _pendiente = null;
    await abrir(mensaje, token);
  }

  /// Marca el aviso como leído y abre el detalle de la reserva.
  Future<void> abrir(RemoteMessage mensaje, String token) async {
    final notificacionId = _texto(mensaje, 'notificacionId') ?? '';
    if (notificacionId.isNotEmpty) {
      try {
        await _notificaciones.marcarLeida(token, notificacionId);
        marcarLeidaLocal();
      } catch (_) {
        // Navegamos igual: el aviso ya se mostró al usuario.
      }
    }
    final reservaId = _texto(mensaje, 'reservaId') ?? '';
    _navegarA(reservaId.isEmpty ? '/avisos' : '/reservas/$reservaId');
  }

  void dispose() {
    for (final suscripcion in _suscripciones) {
      suscripcion.cancel();
    }
    _suscripciones.clear();
    noLeidas.dispose();
  }

  void _alRecibirEnPrimerPlano(RemoteMessage mensaje) {
    noLeidas.value++;
    final contexto = navigatorKey.currentContext;
    if (contexto == null) return;
    final avisos = ScaffoldMessenger.maybeOf(contexto);
    if (avisos == null) return;
    final titulo = mensaje.notification?.title ??
        _texto(mensaje, 'titulo') ??
        MensajesNotificaciones.titulo;
    avisos.showSnackBar(
      SnackBar(
        content: Text(titulo),
        action: SnackBarAction(
          label: MensajesNotificaciones.ver,
          onPressed: () {
            final token = _tokenApi;
            if (token != null) unawaited(abrir(mensaje, token));
          },
        ),
      ),
    );
  }

  void _alAbrirDesdePush(RemoteMessage mensaje) {
    final token = _tokenApi;
    if (token != null) {
      unawaited(abrir(mensaje, token));
    } else {
      _pendiente = mensaje;
    }
  }

  Future<void> _alRenovarToken(String tokenFcm) async {
    if (!_permisoConcedido || tokenFcm.isEmpty) return;
    _tokenFcm = tokenFcm;
    final token = _tokenApi;
    if (token == null) return;
    try {
      await _notificaciones.registrarToken(token, tokenFcm);
    } catch (_) {
      _registrado = false;
    }
  }

  void _navegarA(String ruta) {
    void navegar() {
      navigatorKey.currentState?.pushNamed(ruta);
    }
    if (navigatorKey.currentState != null) {
      navegar();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => navegar());
    }
  }

  void _limpiarSesion() {
    _tokenFcm = null;
    _tokenApi = null;
    _registrado = false;
    _permisoConcedido = false;
    _pendiente = null;
    noLeidas.value = 0;
  }

  String? _texto(RemoteMessage mensaje, String clave) {
    final valor = mensaje.data[clave]?.toString() ?? '';
    return valor.isEmpty ? null : valor;
  }
}
