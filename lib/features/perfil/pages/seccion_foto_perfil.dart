import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/widgets/aviso.dart';
import '../../../core/widgets/estados.dart';
import '../../negocios/pages/fotos_negocio.dart' show ProveedorImagenNegocio;
import '../mensajes.dart';
import 'avatar_perfil.dart';
import 'estilos_perfil.dart';

/// Avatar y acciones de la foto de perfil (HU-C11) al inicio de «Mi perfil».
/// Solo dibuja: la subida y el borrado los hace la pantalla.
class SeccionFotoPerfil extends StatelessWidget {
  const SeccionFotoPerfil({
    super.key,
    required this.nombre,
    required this.proveedor,
    required this.onElegir,
    required this.onQuitar,
    this.url,
    this.vistaPrevia,
    this.ocupado,
    this.error,
    this.onReintentar,
  });

  final String nombre;
  final ProveedorImagenNegocio proveedor;
  final String? url;
  final Uint8List? vistaPrevia;

  /// Texto mientras se sube o se quita; `null` si no hay nada en curso.
  final String? ocupado;
  final String? error;
  final VoidCallback onElegir;
  final VoidCallback onQuitar;

  /// Solo si el fallo se puede reintentar con la misma foto.
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final tieneFoto = url != null;
    final libre = ocupado == null;
    return Column(
      children: [
        AvatarPerfil(
          nombre: nombre,
          proveedor: proveedor,
          url: url,
          vistaPrevia: vistaPrevia,
        ),
        const SizedBox(height: Espacios.m),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Espacios.s,
          runSpacing: Espacios.s,
          children: [
            OutlinedButton.icon(
              key: const Key('boton-foto'),
              onPressed: libre ? onElegir : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                tieneFoto
                    ? MensajesPerfil.cambiarFoto
                    : MensajesPerfil.agregarFoto,
              ),
              style: estiloPildoraSecundaria(context),
            ),
            if (tieneFoto)
              TextButton.icon(
                key: const Key('boton-quitar-foto'),
                onPressed: libre ? onQuitar : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text(MensajesPerfil.quitarFoto),
                style: estiloAccionQuitar(context),
              ),
          ],
        ),
        if (ocupado != null)
          EstadoCargando(compacto: true, mensaje: ocupado)
        else if (error != null) ...[
          const SizedBox(height: Espacios.m),
          Aviso(texto: error!, key: const Key('aviso-foto')),
          if (onReintentar != null) ...[
            const SizedBox(height: Espacios.s),
            TextButton(
              key: const Key('reintentar-foto'),
              onPressed: onReintentar,
              child: const Text(MensajesPerfil.reintentar),
            ),
          ],
        ],
      ],
    );
  }
}
