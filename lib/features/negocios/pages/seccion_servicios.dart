part of 'perfil_negocio_page.dart';

class _SeccionServicios extends StatefulWidget {
  const _SeccionServicios({
    required this.negocioId,
    required this.aceptaReservas,
    required this.service,
  });
  final String negocioId;
  final bool aceptaReservas;
  final NegociosService service;

  @override
  State<_SeccionServicios> createState() => _SeccionServiciosState();
}

class _SeccionServiciosState extends State<_SeccionServicios> {
  List<Servicio>? _servicios;
  Object? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final servicios = await widget.service.obtenerServicios(widget.negocioId);
      if (!mounted) return;
      setState(() {
        _servicios = servicios;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        MensajesNegocios.servicios,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (_cargando)
        const CargaNegocio()
      else if (_error != null)
        ErrorNegocio(
          mensaje: MensajesNegocios.mensajeDeError(_error!),
          onReintentar: MensajesNegocios.puedeReintentar(_error!)
              ? _cargar
              : null,
        )
      else if (_servicios!.isEmpty)
        const Text(MensajesNegocios.sinServicios)
      else
        for (final servicio in _servicios!) _FilaServicio(servicio: servicio),
    ],
  );
}

class _FilaServicio extends StatelessWidget {
  const _FilaServicio({required this.servicio});
  final Servicio servicio;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(servicio.nombre),
    subtitle: Text(formatearDuracion(servicio.duracionMin)),
    trailing: Text(formatearPrecio(servicio.precio)),
  );
}
