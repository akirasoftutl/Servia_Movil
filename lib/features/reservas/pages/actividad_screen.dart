import 'package:flutter/material.dart';

/// Estado vacío de Actividad para usuarios sin sesión.
class ActividadScreen extends StatelessWidget {
  final VoidCallback? onBuscarLugares;
  final VoidCallback? onIniciarSesion;

  const ActividadScreen({
    super.key,
    this.onBuscarLugares,
    this.onIniciarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // El bottom ya lo reserva la barra de navegación del HomePage.
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 52),
              const Text(
                'Actividad',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                  letterSpacing: -0.5,
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _CalendarEmptyIcon(),
                      const SizedBox(height: 20),
                      const Text(
                        'Sin actividad',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Inicia sesión o regístrate para\nadministrar tus citas próximas y\npasadas o ver la actividad',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF7A7A7A),
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: onBuscarLugares ?? () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF141414),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: const Text('Buscar lugares'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: onIniciarSesion ?? () {},
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF141414),
                            side: const BorderSide(
                              color: Color(0xFFE0E0E0),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          child: const Text('Inicia sesión o regístrate'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarEmptyIcon extends StatelessWidget {
  const _CalendarEmptyIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 64,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 8,
            child: Container(
              width: 60,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFC7B8FF),
                    Color(0xFFE6E1FF),
                    Color(0xFFF6F5FB),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            left: 16,
            child: _RingTab(),
          ),
          const Positioned(
            top: 0,
            right: 16,
            child: _RingTab(),
          ),
        ],
      ),
    );
  }
}

class _RingTab extends StatelessWidget {
  const _RingTab();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 15,
      decoration: BoxDecoration(
        color: const Color(0xFF6745E6),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
