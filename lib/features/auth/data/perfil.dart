class Perfil {
  final String uid;
  final String nombre;
  final String correo;
  final String tipo;

  const Perfil({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.tipo,
  });

  factory Perfil.fromJson(Map<String, dynamic> json) {
    return Perfil(
      uid: json['uid'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      tipo: json['tipo'] as String? ?? '',
    );
  }

  bool get esCliente => tipo == 'cliente';
}