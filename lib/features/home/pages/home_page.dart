import 'package:flutter/material.dart';

import '../../auth/data/perfil.dart';
import '../../negocios/data/negocios_service.dart';
import '../../negocios/pages/lista_negocios_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.perfil,
    required this.onCerrarSesion,
    this.negociosService,
  });

  final Perfil perfil;
  final NegociosService? negociosService;
  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servia'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: onCerrarSesion,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListaNegocios(negociosService: negociosService),
    );
  }
}
