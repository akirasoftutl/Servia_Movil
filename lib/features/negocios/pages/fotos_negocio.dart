import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../data/fotos_negocio.dart';
import '../mensajes.dart';

/// Carga de las fotos. Se puede sustituir en pruebas de widget.
typedef ProveedorImagenNegocio = ImageProvider Function(String url);

const _altoPortada = 200.0;
const _altoGaleria = 112.0;
const _anchoGaleria = 160.0;

class PortadaNegocio extends StatelessWidget {
  const PortadaNegocio({
    super.key,
    required this.foto,
    this.proveedor = NetworkImage.new,
  });

  final FotoNegocio foto;
  final ProveedorImagenNegocio proveedor;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Foto de portada del negocio',
    child: SizedBox(
      width: double.infinity,
      height: _altoPortada,
      child: ImagenFotoNegocio(
        url: foto.url,
        proveedor: proveedor,
        ancho: double.infinity,
        alto: _altoPortada,
        radio: Radios.l,
      ),
    ),
  );
}

class GaleriaFotosNegocio extends StatelessWidget {
  const GaleriaFotosNegocio({
    super.key,
    required this.fotos,
    this.proveedor = NetworkImage.new,
  });

  final List<FotoNegocio> fotos;
  final ProveedorImagenNegocio proveedor;

  @override
  Widget build(BuildContext context) {
    if (fotos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MensajesNegocios.galeria,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: Espacios.m),
        SizedBox(
          height: _altoGaleria,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: fotos.length,
            separatorBuilder: (_, _) => const SizedBox(width: Espacios.s),
            itemBuilder: (context, indice) => SizedBox(
              key: Key('foto-galeria-$indice'),
              width: _anchoGaleria,
              child: ImagenFotoNegocio(
                url: fotos[indice].url,
                proveedor: proveedor,
                ancho: _anchoGaleria,
                alto: _altoGaleria,
                radio: Radios.m,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Imagen con esquinas redondeadas y marcador neutro si no carga. La usan la
/// portada, la galería y las imágenes de cada servicio.
class ImagenFotoNegocio extends StatelessWidget {
  const ImagenFotoNegocio({
    super.key,
    required this.url,
    required this.proveedor,
    required this.ancho,
    required this.alto,
    required this.radio,
  });

  final String url;
  final ProveedorImagenNegocio proveedor;
  final double ancho;
  final double alto;
  final double radio;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.all(Radius.circular(radio)),
    child: Image(
      image: proveedor(url),
      width: ancho,
      height: alto,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          _MarcadorFotoNegocio(ancho: ancho, alto: alto),
    ),
  );
}

class _MarcadorFotoNegocio extends StatelessWidget {
  const _MarcadorFotoNegocio({required this.ancho, required this.alto});

  final double ancho;
  final double alto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: ancho,
      height: alto,
      alignment: Alignment.center,
      color: tema.colorScheme.surfaceContainerHighest,
      child: Semantics(
        label: 'Imagen no disponible',
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
