import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/negocio.dart';
import '../data/negocios_service.dart';
import '../formatos.dart';
import '../mensajes.dart';
part 'estados_consulta.dart';

class PerfilNegocioPage extends StatefulWidget {
  const PerfilNegocioPage({
    super.key,
    required this.negocioId,
    this.negociosService,
  });

  final String negocioId;
  final NegociosService? negociosService;

  @override
  State<PerfilNegocioPage> createState() => _PerfilNegocioPageState();
}

class _PerfilNegocioPageState extends State<PerfilNegocioPage> {
  late final NegociosService _service;
  Negocio? _negocio;
  String? _categoria;
  Object? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _service = widget.negociosService ?? NegociosService();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    if (!esIdValido(widget.negocioId)) {
      setState(() {
        _cargando = false;
        _error = const ApiException(404, MensajesNegocios.noDisponible);
      });
      return;
    }
    try {
      final negocio = await _service.obtenerNegocio(widget.negocioId);
      if (!mounted) return;
      setState(() {
        _negocio = negocio;
        _categoria = negocio.categoriaId;
        _cargando = false;
      });
      _cargarCategoria(negocio.categoriaId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _cargando = false;
      });
    }
  }

  Future<void> _cargarCategoria(String categoriaId) async {
    try {
      final categorias = await _service.obtenerCategorias();
      if (!mounted) return;
      for (final categoria in categorias) {
        if (categoria.id == categoriaId) {
          setState(() => _categoria = categoria.nombre);
          return;
        }
      }
    } catch (_) {
      if (!mounted) return;
      // D2: el catálogo no impide consultar el perfil.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(MensajesNegocios.tituloPerfil)),
    body: _cargando
        ? const _PantallaCarga()
        : _error != null
        ? _PantallaErrorRed(error: _error!, onReintentar: _cargar)
        : _ContenidoPerfil(negocio: _negocio!, categoria: _categoria!),
  );
}

class _ContenidoPerfil extends StatelessWidget {
  const _ContenidoPerfil({required this.negocio, required this.categoria});
  final Negocio negocio;
  final String categoria;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EncabezadoNegocio(negocio: negocio, categoria: categoria),
        const SizedBox(height: 16),
        _ContactoNegocio(negocio: negocio),
        const SizedBox(height: 24),
        _HorarioSemanal(horario: negocio.horario),
      ],
    ),
  );
}

class _EncabezadoNegocio extends StatelessWidget {
  const _EncabezadoNegocio({required this.negocio, required this.categoria});
  final Negocio negocio;
  final String categoria;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(negocio.nombre, style: Theme.of(context).textTheme.headlineSmall),
      if (negocio.descripcion != null) Text(negocio.descripcion!),
      Text(categoria),
      Text(
        negocio.aceptaReservas
            ? MensajesNegocios.aceptaReservas
            : MensajesNegocios.noAceptaReservas,
      ),
    ],
  );
}

class _ContactoNegocio extends StatelessWidget {
  const _ContactoNegocio({required this.negocio});
  final Negocio negocio;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (negocio.direccion != null) Text(negocio.direccion!),
      if (negocio.telefono != null) Text(negocio.telefono!),
      if (negocio.correoContacto != null) Text(negocio.correoContacto!),
    ],
  );
}

class _HorarioSemanal extends StatelessWidget {
  const _HorarioSemanal({required this.horario});
  final Map<String, HorarioDia?> horario;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        MensajesNegocios.horario,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final dia in diasSemana.entries)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(dia.value), Text(formatearHorario(horario[dia.key]))],
        ),
    ],
  );
}
