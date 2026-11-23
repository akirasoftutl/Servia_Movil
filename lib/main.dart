import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/firebase/firebase_options.dart';
import 'core/theme/tema_servia.dart';
import 'features/auth/pages/auth_gate.dart';
import 'features/negocios/rutas_negocios.dart';
import 'features/notificaciones/data/servicio_push.dart';
import 'features/notificaciones/rutas_notificaciones.dart';
import 'features/reservas/rutas_reservas.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
          generarRutaNegocios(ajustes),
      onUnknownRoute: generarRutaNoDisponible,
    );
  }
}
