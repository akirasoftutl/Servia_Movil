import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../data/fotos_negocio.dart';
import '../mensajes.dart';
import 'fotos_negocio.dart';

const _altoImagen = 200.0;

// Con varias imágenes la siguiente asoma para que se vea que se desliza.
const _fraccionConVarias = 0.82;

/// Por encima de esta escala de texto la fila del servicio pierde la
/// miniatura para dejar el ancho al nombre y al botón.
const _escalaMaximaMiniatura = 1.2;

/// Imágenes del servicio (HU-C32, T19: hasta 3) en una franja horizontal.
///
/// Reutiliza [ImagenFotoNegocio] y [ProveedorImagenNegocio] de las fotos del
/// negocio, con su marcador cuando una imagen no carga. Sin imágenes no ocupa
/// nada. Solo se construyen y decodifican las que se ven, a su tamaño.
class ImagenesServicio extends StatelessWidget {
  const ImagenesServicio({
    super.key,
    required this.imagenes,
    required this.nombreServicio,
    this.proveedor = NetworkImage.new,
  });

  final List<FotoNegocio> imagenes;
  final String nombreServicio;
  final ProveedorImagenNegocio proveedor;

  @override
  Widget build(BuildContext context) {
    if (imagenes.isEmpty) return const SizedBox.shrink();
    final pixeles = MediaQuery.devicePixelRatioOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, limites) {
            final ancho = imagenes.length > 1
                ? limites.maxWidth * _fraccionConVarias
                : limites.maxWidth;
            return SizedBox(
              height: _altoImagen,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: imagenes.length,
                separatorBuilder: (_, _) => const SizedBox(width: Espacios.s),
                itemBuilder: (context, indice) => Semantics(
                  image: true,
                  label: MensajesNegocios.imagenDeServicio(
                    indice + 1,
                    imagenes.length,
                    nombreServicio,
                  ),
                  child: SizedBox(
                    key: Key('imagen-servicio-$indice'),
                    width: ancho,
                    child: ImagenFotoNegocio(
                      url: imagenes[indice].url,
                      proveedor: _aTamano(proveedor, ancho * pixeles),
                      ancho: ancho,
                      alto: _altoImagen,
                      radio: Radios.m,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: Espacios.l),
      ],
    );
  }
}

/// Miniatura de la primera imagen en la fila del servicio. Es decorativa para
/// lectores de pantalla: las imágenes completas están en el detalle.
class MiniaturaServicio extends StatelessWidget {
  const MiniaturaServicio({
    super.key,
    required this.servicioId,
    required this.imagen,
    this.proveedor = NetworkImage.new,
  });

  final String servicioId;
  final FotoNegocio imagen;
  final ProveedorImagenNegocio proveedor;

  /// Con texto muy grande la fila no la muestra.
  static bool cabe(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) <= _escalaMaximaMiniatura;

  @override
  Widget build(BuildContext context) {
    final pixeles = MediaQuery.devicePixelRatioOf(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        key: Key('miniatura-servicio-$servicioId'),
        dimension: Medidas.miniatura,
        child: ImagenFotoNegocio(
          url: imagen.url,
          proveedor: _aTamano(proveedor, Medidas.miniatura * pixeles),
          ancho: Medidas.miniatura,
          alto: Medidas.miniatura,
          radio: Radios.s,
        ),
      ),
    );
  }
}

/// Decodifica a lo que se pinta, no a la foto completa.
ProveedorImagenNegocio _aTamano(ProveedorImagenNegocio base, double pixeles) =>
    (url) => ResizeImage.resizeIfNeeded(pixeles.ceil(), null, base(url));
