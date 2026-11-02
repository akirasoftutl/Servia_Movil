import 'package:flutter/material.dart';

import '../../auth/data/auth_service.dart';
import '../../negocios/data/negocios_service.dart';
import '../../negocios/pages/lista_negocios_page.dart';
import '../../perfil/data/perfil_cliente_service.dart';
import '../../perfil/pages/mi_perfil_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onCerrarSesion,
    this.negociosService,
    this.authService,
    this.perfilClienteService,
  });

  final NegociosService? negociosService;
  final AuthService? authService;
  final PerfilClienteService? perfilClienteService;
  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servia'),
        actions: [
          IconButton(
            tooltip: 'Mi perfil',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MiPerfilPage(
                  authService: authService,
                  perfilClienteService: perfilClienteService,
                ),
              ),
            ),
            icon: const Icon(Icons.person_outline),
          ),
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
