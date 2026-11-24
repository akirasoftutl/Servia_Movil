import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// La imagen que eligió el cliente.
class FotoElegida {
  const FotoElegida({required this.bytes, required this.nombre});

  final Uint8List bytes;
  final String nombre;
}

/// Quien deja elegir una foto; las pruebas lo reemplazan por uno simulado.
abstract interface class SelectorFoto {
  /// `null` si el cliente cierra el selector sin elegir.
  Future<FotoElegida?> elegir();
}

/// Galería del sistema (`image_picker`). En Android 13 o más nuevo usa el
/// selector de fotos del sistema y no pide permisos.
class SelectorFotoGaleria implements SelectorFoto {
  SelectorFotoGaleria({ImagePicker? selector})
    : _selector = selector ?? ImagePicker();

  final ImagePicker _selector;

  @override
  Future<FotoElegida?> elegir() async {
    final archivo = await _selector.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (archivo == null) return null;
    return FotoElegida(
      bytes: await archivo.readAsBytes(),
      nombre: archivo.name,
    );
  }
}
