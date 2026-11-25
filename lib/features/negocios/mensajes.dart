import '../../core/network/api_exception.dart';

class MensajesNegocios {
  MensajesNegocios._();

  static const ubicacion = 'Ubicación';
  static const descripcionMapa = 'Mapa con la ubicación del negocio';
  static const comoLlegar = 'Cómo llegar';
  static const errorMapa = 'No se pudo cargar el mapa.';
  static const errorAppMapas = 'No se pudo abrir la app de mapas.';

  static const destacados = 'Destacados';
  static const tuUbicacion = 'Tu ubicación';
  static const errorCercanos = 'No se pudieron cargar los negocios cercanos.';
  static const sinCercanos = 'No hay negocios cerca de ti.';
  static const cercaDeTi = 'Cerca de ti';
  static String distancia(double km) => 'a ${km.toStringAsFixed(1)} km';
  static String distanciaCorta(double km) => '${km.toStringAsFixed(1)} km';
  static String descripcionPin(String nombre, double km) =>
      '$nombre ${distancia(km)}';
  static const descripcionMapaCercanos =
      'Mapa de negocios cercanos. Toca un pin para ver el negocio.';
  static const buscandoCercanos = 'Buscando negocios cerca de ti…';
  static const hojaAbierta =
      'Hoja de contenido. Desliza hacia abajo para ver el mapa';
  static const hojaColapsada =
      'Hoja de contenido. Desliza hacia arriba para ver el contenido';
  static const asaVerMapa = 'Bajar la hoja y ampliar el mapa';
  static const asaVerContenido = 'Subir la hoja y ver el contenido';

  static const errorRed =
      'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.';
  static const noDisponible = 'Este negocio no está disponible.';
  static const paginaNoExiste = 'Esta página no existe.';
  static const errorApi = 'La API no está disponible. Intenta más tarde.';
  static const errorCarga =
      'Ocurrió un error al cargar el negocio. Inténtalo de nuevo.';
  static const reintentar = 'Reintentar';
  static const descanso = 'Descanso';
  static const aceptaReservas = 'Acepta reservas';
  static const noAceptaReservas = 'No acepta reservas por ahora';
  static const tituloPerfil = 'Perfil del negocio';
  static const buscar = 'Buscar negocios o servicios';
  static const limpiar = 'Limpiar búsqueda';
  static const todas = 'Todas';
  static const filtrarPorCategoria = 'Filtrar servicios por categoría';
  static String categoriaDelServicio(String nombre) => 'Categoría: $nombre';
  static const sinResultados = 'No encontramos negocios con esa búsqueda';
  static const busquedaInvalida =
      'Revisa la búsqueda y la categoría e inténtalo de nuevo.';
  static const tituloLista = 'Negocios';
  static const cargarMas = 'Cargar más negocios';
  static const listaVacia = 'Todavía no hay negocios disponibles';
  static const verSinSesion = 'Ver negocios sin iniciar sesión';
  static const servicios = 'Servicios';
  static const sinServicios =
      'Este negocio aún no tiene servicios disponibles.';
  static const servicioNoDisponible = 'Este servicio ya no está disponible.';
  static const reservar = 'Reservar';
  static const detalleServicio = 'Detalle del servicio';
  static String imagenDeServicio(int posicion, int total, String servicio) =>
      'Imagen $posicion de $total de $servicio';
  static const horario = 'Horario de atención';
  static const galeria = 'Galería';

  static const sesionVencida =
      'Tu sesión ya no es válida. Inicia sesión de nuevo.';

  static String mensajeDeError(Object error, {bool esServicio = false}) {
    if (error is ApiException) {
      // Solo la disponibilidad de una reserva propia pide sesión (T18).
      if (error.statusCode == 401 || error.statusCode == 403) {
        return sesionVencida;
      }
      if (error.statusCode == 404) {
        return esServicio ? servicioNoDisponible : noDisponible;
      }
      if (error.statusCode >= 500) return errorApi;
    }
    if (error is FormatException) return errorCarga;
    return errorRed;
  }

  static bool puedeReintentarBusqueda(Object error) =>
      error is! ApiException || error.statusCode != 400;

  static String mensajeDeErrorBusqueda(Object error) =>
      puedeReintentarBusqueda(error) ? mensajeDeError(error) : busquedaInvalida;

  static bool puedeReintentar(Object error) =>
      error is! ApiException ||
      (error.statusCode != 404 &&
          error.statusCode != 401 &&
          error.statusCode != 403);
}
