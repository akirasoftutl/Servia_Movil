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

  // Eliminar la cuenta (HU-C14).
  static const eliminarCuenta = 'Eliminar mi cuenta';
  static const eliminarConfirmar = 'Eliminar cuenta';
  static const eliminarTitulo = '¿Eliminar tu cuenta?';
  static const eliminarSeElimina =
      'Se eliminan tu perfil y tus datos personales, tus favoritos y tu foto, y dejas de recibir avisos en este teléfono.';
  static const eliminarSeConserva =
      'Tus reservas pasadas se conservan para el historial del negocio, sin tu nombre ni tus datos personales.';
  static const eliminarIrreversible =
      'No se puede deshacer. Para confirmar, escribe tu contraseña.';
  static const contrasenaActual = 'Contraseña actual';
  static const eliminarContrasenaObligatoria =
      'La contraseña actual es obligatoria.';
  static const eliminandoCuenta = 'Eliminando tu cuenta…';
  static const cuentaEliminada = 'Tu cuenta se eliminó.';
  static const verMisReservas = 'Ver mis reservas';
  static const mostrarContrasena = 'Mostrar contraseña';
  static const ocultarContrasena = 'Ocultar contraseña';
  static const eliminarConReservas =
      'No puedes eliminar tu cuenta porque tienes reservas pendientes o confirmadas. Cancélalas o espera a que terminen.';
  static const eliminarNoSePudo =
      'No se pudo eliminar tu cuenta. Vuelve a intentarlo en unos minutos.';
}
