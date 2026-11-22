import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/firebase/firebase_options.dart';
import 'core/theme/tema_servia.dart';
import 'features/auth/pages/auth_gate.dart';
import 'features/negocios/rutas_negocios.dart';
import 'features/reservas/rutas_reservas.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ServiaApp());
}

class ServiaApp extends StatelessWidget {
  const ServiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Servia',
      theme: temaServia(),
      home: const AuthGate(),
      onGenerateRoute: (ajustes) =>
          generarRutaReservas(ajustes) ?? generarRutaNegocios(ajustes),
      onUnknownRoute: generarRutaNoDisponible,
    );
  }
}