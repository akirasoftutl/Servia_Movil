import 'package:flutter/material.dart';

import '../../auth/data/perfil.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.perfil,
    required this.onCerrarSesion,
  });

  final Perfil perfil;
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: Color(0xFF7B1FA2),
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              perfil.nombre.isEmpty ? 'Cliente' : perfil.nombre,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              perfil.correo,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onCerrarSesion,
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                side: const BorderSide(color: Color(0xFF7B1FA2)),
                foregroundColor: const Color(0xFF7B1FA2),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}