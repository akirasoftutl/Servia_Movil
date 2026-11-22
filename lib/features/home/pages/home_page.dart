import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/marca_servia.dart';
import '../../auth/data/auth_service.dart';
import '../../negocios/data/negocios_service.dart';
import '../../negocios/data/ubicacion_cliente.dart';
import '../../negocios/pages/lista_negocios_page.dart';
import '../../negocios/pages/negocios_cercanos.dart';
import '../../perfil/data/perfil_cliente_service.dart';
import '../../perfil/pages/mi_perfil_page.dart';
import '../../reservas/data/reservas_service.dart';
import '../../reservas/pages/mis_reservas_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onCerrarSesion,
    this.negociosService,
    this.proveedorUbicacion,
    this.authService,
    this.perfilClienteService,
    this.reservasService,
  });

  final NegociosService? negociosService;
  final ProveedorUbicacionCliente? proveedorUbicacion;
  final AuthService? authService;
  final PerfilClienteService? perfilClienteService;
  final ReservasService? reservasService;
  final VoidCallback onCerrarSesion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoServia(tamano: 28),
            SizedBox(width: Espacios.s),
            Text('Servia'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mis reservas',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MisReservasPage(
                  authService: authService,
                  reservasService: reservasService,
                ),
              ),
            ),
            icon: const Icon(Icons.event_note),
          ),
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
      body: Column(
        children: [
          NegociosCercanos(
            service: negociosService,
            proveedorUbicacion: proveedorUbicacion,
          ),
          Expanded(child: ListaNegocios(negociosService: negociosService)),
        ],
      ),
    );
  }
}
