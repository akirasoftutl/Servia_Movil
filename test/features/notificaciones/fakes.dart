import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:servia/features/notificaciones/data/aviso.dart';
import 'package:servia/features/notificaciones/data/messaging_client.dart';
import 'package:servia/features/notificaciones/data/notificaciones_service.dart';

class NotificacionesFalso extends NotificacionesService {
  NotificacionesFalso({
    Map<String?, PaginaAvisos>? paginas,
    this.noLeidas = 0,
    this.error,
    Map<String?, Object>? erroresPorPagina,
    List<Map<String, String>>? registros,
    List<Map<String, String>>? bajas,
    List<String>? marcadas,
  }) : paginas =
           paginas ??
           {
             null: PaginaAvisos(
               items: const [],
               noLeidas: noLeidas,
               siguiente: null,
             ),
           },
       erroresPorPagina = erroresPorPagina ?? const {},
       registros = registros ?? [],
       bajas = bajas ?? [],
       marcadas = marcadas ?? [];

  /// Clave: cursor de la petición (`null` para la primera página).
  final Map<String?, PaginaAvisos> paginas;
  final int noLeidas;
  Object? error;
  final Map<String?, Object> erroresPorPagina;
  final List<Map<String, String>> registros;
  final List<Map<String, String>> bajas;
  final List<String> marcadas;
  final List<String> tokensMarcadas = [];

  @override
  Future<PaginaAvisos> listar(String token, {String? cursor}) async {
    if (error != null) throw error!;
    final errorPagina = erroresPorPagina[cursor];
    if (errorPagina != null) throw errorPagina;
    final pagina = paginas[cursor];
    if (pagina != null) return pagina;
    return PaginaAvisos(items: const [], noLeidas: noLeidas, siguiente: null);
  }

  @override
  Future<void> registrarToken(String token, String tokenFcm) async {
    registros.add({'token': token, 'tokenFcm': tokenFcm});
  }

  @override
  Future<void> desactivarToken(String token, String tokenFcm) async {
    bajas.add({'token': token, 'tokenFcm': tokenFcm});
  }

  @override
  Future<void> marcarLeida(String token, String id) async {
    marcadas.add(id);
    tokensMarcadas.add(token);
  }
}

class MessagingFalso extends MessagingClient {
  MessagingFalso({
    this.permisoConcedido = true,
    this.token = 'token-fcm',
    this.mensajeInicial,
    this.errorPermiso,
    this.errorToken,
  });

  late final NotificationSettings settings = NotificationSettings(
    authorizationStatus: permisoConcedido
        ? AuthorizationStatus.authorized
        : AuthorizationStatus.denied,
    alert: permisoConcedido
        ? AppleNotificationSetting.enabled
        : AppleNotificationSetting.disabled,
    announcement: AppleNotificationSetting.disabled,
    badge: AppleNotificationSetting.disabled,
    carPlay: AppleNotificationSetting.disabled,
    criticalAlert: AppleNotificationSetting.disabled,
    lockScreen: AppleNotificationSetting.disabled,
    notificationCenter: AppleNotificationSetting.disabled,
    providesAppNotificationSettings: AppleNotificationSetting.disabled,
    showPreviews: AppleShowPreviewSetting.never,
    sound: AppleNotificationSetting.disabled,
    timeSensitive: AppleNotificationSetting.disabled,
  );

  final bool permisoConcedido;
  final String token;
  final RemoteMessage? mensajeInicial;
  final Object? errorPermiso;
  final Object? errorToken;

  final mensajes = StreamController<RemoteMessage>.broadcast();
  final aperturas = StreamController<RemoteMessage>.broadcast();
  final refrescos = StreamController<String>.broadcast();

  int solicitudesPermiso = 0;
  int tokensObtenidos = 0;

  @override
  Future<NotificationSettings> requestPermission() async {
    solicitudesPermiso++;
    if (errorPermiso != null) throw errorPermiso!;
    return settings;
  }

  @override
  Stream<RemoteMessage> get onMessage => mensajes.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => aperturas.stream;

  @override
  Future<String?> getToken() async {
    tokensObtenidos++;
    if (errorToken != null) throw errorToken!;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => refrescos.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => mensajeInicial;
}

Aviso avisoPrueba({
  String id = 'a1',
  String titulo = 'Reserva confirmada',
  String cuerpo = 'Tu reserva quedó confirmada.',
  bool leida = false,
  DateTime? creadaEn,
  String? reservaId = 'r1',
  String tipo = 'reserva.confirmada',
}) => Aviso(
  id: id,
  tipo: tipo,
  titulo: titulo,
  cuerpo: cuerpo,
  leida: leida,
  creadaEn: creadaEn ?? DateTime.utc(2026, 11, 22, 10),
  reservaId: reservaId,
);

RemoteMessage mensajePrueba({
  String notificacionId = 'a1',
  String? reservaId = 'r1',
  String titulo = 'Reserva confirmada',
  String cuerpo = 'Tu reserva quedó confirmada.',
  String tipo = 'reserva.confirmada',
}) => RemoteMessage(
  data: <String, dynamic>{
    'tipo': tipo,
    'notificacionId': notificacionId,
    'reservaId': ?reservaId,
  },
  notification: RemoteNotification(title: titulo, body: cuerpo),
);
