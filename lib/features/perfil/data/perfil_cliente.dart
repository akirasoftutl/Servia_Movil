class PerfilCliente {
  final String nombre;
  final String correo;
  final String telefono;

  const PerfilCliente({
    required this.nombre,
    required this.correo,
    required this.telefono,
  });

  factory PerfilCliente.fromJson(Map<String, dynamic> json) {
    return PerfilCliente(
      nombre: json['nombre'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
    );
  }
}
