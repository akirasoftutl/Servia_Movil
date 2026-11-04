import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Logo de Servia (el «S» naranja del panel, `Servia_UI/public`).
///
/// Con [enMosaico] se dibuja sobre una pieza blanca redondeada, como el ícono
/// de la app; se usa en el arranque, el inicio de sesión y el registro.
class LogoServia extends StatelessWidget {
  const LogoServia({
    super.key,
    this.tamano = Medidas.logo,
    this.enMosaico = false,
  });

  final double tamano;
  final bool enMosaico;

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/images/logo_servia.png',
      width: enMosaico ? tamano * 0.6 : tamano,
      height: enMosaico ? tamano * 0.6 : tamano,
      semanticLabel: 'Servia',
      filterQuality: FilterQuality.medium,
    );
    if (!enMosaico) return logo;
    final c = Theme.of(context).colorScheme;
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(tamano * 0.28),
        border: Border.all(color: c.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: logo,
    );
  }
}
