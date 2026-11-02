/// Validaciones de los datos de un cliente. Las usan el registro (MVP-01) y
/// «Mi perfil» (MVP-05) para que ambos pidan lo mismo y muestren los mismos textos.
class ValidacionesCliente {
  ValidacionesCliente._();

  static String? nombre(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es obligatorio.';
    }
    if (value.trim().length < 2) {
      return 'El nombre debe tener al menos 2 caracteres.';
    }
    if (value.trim().length > 100) {
      return 'El nombre no puede exceder 100 caracteres.';
    }
    return null;
  }

  static String? correo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es obligatorio.';
    }
    final correo = value.trim();
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!regex.hasMatch(correo)) {
      return 'El correo debe tener un formato válido.';
    }
    return null;
  }

  static String? telefono(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El teléfono es obligatorio.';
    }
    final tel = value.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(tel)) {
      return 'El teléfono debe contener exactamente 10 dígitos numéricos.';
    }
    return null;
  }
}
