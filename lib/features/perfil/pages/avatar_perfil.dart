import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../negocios/pages/fotos_negocio.dart' show ProveedorImagenNegocio;
import '../mensajes.dart';

/// Avatar del cliente: su foto en círculo o, si no hay (o no carga), la
/// inicial del nombre sobre el tono de marca, como `MiniaturaNegocio`.
class AvatarPerfil extends StatelessWidget {
  const AvatarPerfil({
    super.key,
    required this.nombre,
    required this.proveedor,
    this.url,
    this.vistaPrevia,
    this.tamano = Medidas.logo,
  });

  final String nombre;
  final ProveedorImagenNegocio proveedor;

  /// Foto guardada en la API.
  final String? url;

  /// Foto recién elegida que aún se sube: se ve mientras tanto.
  final Uint8List? vistaPrevia;
  final double tamano;

  String get _inicial {
    final limpio = nombre.trim();
    return limpio.isEmpty ? 'U' : limpio.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = tema.colorScheme;
    final tieneFoto = vistaPrevia != null || url != null;
    final inicial = ExcludeSemantics(
      child: Center(
        child: Text(
          _inicial,
          // La inicial es decorativa y la pieza tiene tamaño fijo.
          textScaler: TextScaler.noScaling,
          style: tema.textTheme.headlineMedium?.copyWith(
            height: 1,
            color: c.onPrimaryContainer,
          ),
        ),
      ),
    );
    final ImageProvider? imagen = vistaPrevia != null
        ? MemoryImage(vistaPrevia!)
        : (url != null ? proveedor(url!) : null);
    return Semantics(
      image: true,
      label: tieneFoto
          ? MensajesPerfil.semanticaFoto(nombre)
          : MensajesPerfil.semanticaSinFoto(nombre),
      child: Container(
        key: const Key('avatar-perfil'),
        width: tamano,
        height: tamano,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: imagen == null
            ? inicial
            : ExcludeSemantics(
                child: Image(
                  image: imagen,
                  width: tamano,
                  height: tamano,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => inicial,
                ),
              ),
      ),
    );
  }
}
