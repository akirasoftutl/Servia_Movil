class MensajesPerfil {
  MensajesPerfil._();

  static const titulo = 'Mi perfil';
  static const guardado = 'Tus datos se guardaron.';
  static const correoEnUso = 'Ese correo ya está en uso.';
  static const iniciaConNuevoCorreo = 'Inicia sesión con el nuevo correo.';
  static const sesionInvalida =
      'No se pudo verificar tu sesión. Vuelve a iniciar sesión.';
  static const soloClientes = 'Esta pantalla es solo para cuentas de cliente.';
  static const cuentaDesactivada =
      'Tu cuenta está desactivada. Ponte en contacto con soporte para más información.';
  static const sinPerfil = 'Tu cuenta no tiene un perfil registrado.';
  static const errorApi = 'La API no está disponible. Intenta más tarde.';
  static const datosInvalidos = 'Revisa tus datos e inténtalo de nuevo.';
  static const errorGeneral = 'No se pudo completar la operación.';

  // Foto de perfil (HU-C11).
  static const agregarFoto = 'Agregar foto';
  static const cambiarFoto = 'Cambiar foto';
  static const quitarFoto = 'Quitar foto';
  static const cancelar = 'Cancelar';
  static const reintentar = 'Reintentar';
  static const fotoActualizada = 'Foto actualizada.';
  static const fotoEliminada = 'Foto eliminada.';
  static const subiendoFoto = 'Subiendo la foto…';
  static const quitandoFoto = 'Quitando la foto…';
  static const fotoGrande = 'La foto supera el tamaño máximo de 5 MB.';
  static const fotoFormato = 'Elige una imagen JPEG, PNG o WebP.';
  static const fotoNoElegida =
      'No se pudo abrir tu galería. Inténtalo de nuevo.';
  static const fotoNoGuardada =
      'No se pudo guardar la foto. Inténtalo más tarde.';
  static const fotoNoQuitada =
      'No se pudo quitar la foto. Inténtalo más tarde.';
  static const quitarTitulo = '¿Quitar tu foto?';
  static const quitarCuerpo =
      'Se mostrará la inicial de tu nombre. Puedes agregar otra foto cuando quieras.';

  static String semanticaFoto(String nombre) => 'Foto de perfil de $nombre';
  static String semanticaSinFoto(String nombre) =>
      'Sin foto de perfil; se muestra la inicial de $nombre';
}
