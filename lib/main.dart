import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/firebase/firebase_options.dart';
import 'core/theme/tema_servia.dart';
import 'features/auth/pages/auth_gate.dart';
import 'features/favoritos/rutas_favoritos.dart';
import 'features/negocios/rutas_negocios.dart';
import 'features/notificaciones/data/servicio_push.dart';
import 'features/notificaciones/rutas_notificaciones.dart';
import 'features/reservas/rutas_reservas.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En iOS el plist `GoogleService-Info.plist` ya trae las opciones; en
  // Android seguimos usando el archivo Dart generado desde google-services.json.
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await Firebase.initializeApp();
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // google_sign_in 7 exige inicializar el singleton una sola vez. Si faltan
  // credenciales nativas, el login con Google mostrará su mensaje y el acceso
  // con correo sigue funcionando.
  try {
    await GoogleSignIn.instance.initialize();
  } catch (_) {
    // Configuración incompleta: se reporta al pulsar «Continuar con Google».
  }

  final push = ServicioPush.instancia;
  push.configurar();
  // Si la app se abrió tocando una notificación, se guarda hasta que AuthGate
  // confirme la sesión y pueda marcar el aviso como leído.
  await push.cargarMensajeInicial();

  runApp(ServiaApp(push: push));
}

class ServiaApp extends StatelessWidget {
  const ServiaApp({super.key, this.push});

  /// Compartido por el navegador, la campana y el manejo de mensajes FCM.
  final ServicioPush? push;

  @override
  Widget build(BuildContext context) {
    final push = this.push ?? ServicioPush.instancia;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Servia',
      theme: temaServia(),
      navigatorKey: push.navigatorKey,
      home: AuthGate(push: push),
      onGenerateRoute: (ajustes) =>
          generarRutaReservas(ajustes) ??
          generarRutaNotificaciones(ajustes, push: push) ??
          generarRutaFavoritos(ajustes) ??
          generarRutaNegocios(ajustes),
      onUnknownRoute: generarRutaNoDisponible,
    );
  }
}
