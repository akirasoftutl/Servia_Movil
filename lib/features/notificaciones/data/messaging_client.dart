import 'package:firebase_messaging/firebase_messaging.dart';

/// Envoltorio delgado sobre [FirebaseMessaging] para poder simularlo en tests.
///
/// Toda la integración con FCM de la app pasa por aquí; el resto del código
/// nunca llama a `FirebaseMessaging.instance` directamente.
class MessagingClient {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Future<NotificationSettings> requestPermission() => _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

  Future<String?> getToken() => _messaging.getToken();

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();
}
