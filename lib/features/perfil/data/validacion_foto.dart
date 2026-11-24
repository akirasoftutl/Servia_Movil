import 'dart:typed_data';

import '../mensajes.dart';

/// Revisa la foto antes de subirla para avisar rápido y no gastar datos. La
/// API vuelve a validar (tipo por los bytes reales y tamaño) y decide.
abstract final class ValidacionFoto {
  /// Tamaño máximo de la foto: 5 MB (T19).
  static const maxBytes = 5 * 1024 * 1024;

  /// Mensaje de error, o `null` si la foto puede subirse.
  static String? validar(Uint8List bytes) {
    if (extension(bytes) == null) return MensajesPerfil.fotoFormato;
    if (bytes.length > maxBytes) return MensajesPerfil.fotoGrande;
    return null;
  }

  /// `jpg`, `png` o `webp` según la firma del archivo; `null` si es otro
  /// formato. No se fía del nombre ni de la extensión.
  static String? extension(Uint8List b) {
    bool empieza(List<int> firma, [int desde = 0]) {
      if (b.length < desde + firma.length) return false;
      for (var i = 0; i < firma.length; i++) {
        if (b[desde + i] != firma[i]) return false;
      }
      return true;
    }

    if (empieza(const [0xFF, 0xD8, 0xFF])) return 'jpg';
    if (empieza(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'png';
    }
    // WebP: «RIFF» + 4 bytes de tamaño + «WEBP».
    if (empieza('RIFF'.codeUnits) && empieza('WEBP'.codeUnits, 8)) {
      return 'webp';
    }
    return null;
  }
}
