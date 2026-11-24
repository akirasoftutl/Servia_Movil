import 'foto_perfil.dart';

class PerfilCliente {
  final String nombre;
  final String correo;
  final String telefono;

  /// `null` si el cliente no tiene foto (HU-C11).
  final FotoPerfil? foto;

  const PerfilCliente({
    required this.nombre,
    required this.correo,
    required this.telefono,
    this.foto,
  });

  factory PerfilCliente.fromJson(Map<String, dynamic> json) {
    return PerfilCliente(
      nombre: json['nombre'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      foto: FotoPerfil.deJson(json['foto']),
    );
  }

  PerfilCliente conFoto(FotoPerfil? foto) => PerfilCliente(
    nombre: nombre,
    correo: correo,
    telefono: telefono,
    foto: foto,
  );
}
