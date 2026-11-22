Map<String, dynamic> leerObjeto(Object? valor) {
  if (valor is! Map<String, dynamic>) {
    throw const FormatException('Se esperaba un objeto.');
  }
  return valor;
}

String leerTexto(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  if (valor is! String) throw FormatException('Campo inválido: $campo.');
  return valor;
}

String? leerTextoOpcional(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  if (valor == null) return null;
  final texto = leerTexto(json, campo);
  return texto.isEmpty ? null : texto;
}

bool leerBooleano(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  if (valor is! bool) throw FormatException('Campo inválido: $campo.');
  return valor;
}

int leerEntero(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  if (valor is! int) throw FormatException('Campo inválido: $campo.');
  return valor;
}

double leerNumero(Map<String, dynamic> json, String campo) {
  final valor = json[campo];
  if (valor is! num || !valor.isFinite) {
    throw FormatException('Campo inválido: $campo.');
  }
  return valor.toDouble();
}
