import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class RegistroClienteRequest {
  final String nombre;
  final String correo;
  final String telefono;
  final String contrasena;

  const RegistroClienteRequest({
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.contrasena,
  });

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'correo': correo,
        'telefono': telefono,
        'contrasena': contrasena,
      };
}

class RegistroClienteResponse {
  final String id;
  final String nombre;
  final String correo;
  final String telefono;
  final String tipo;

  const RegistroClienteResponse({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.tipo,
  });

  factory RegistroClienteResponse.fromJson(Map<String, dynamic> json) {
    return RegistroClienteResponse(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      correo: json['correo'] as String,
      telefono: json['telefono'] as String,
      tipo: json['tipo'] as String,
    );
  }
}

class RegistroClienteService {
  final ApiClient _api;

  RegistroClienteService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<RegistroClienteResponse> registrarCliente(
    RegistroClienteRequest request,
  ) async {
    final respuesta = await _api.post(
      '/auth/registro/cliente',
      body: jsonEncode(request.toJson()),
    );

    if (respuesta.statusCode == 201) {
      final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
      return RegistroClienteResponse.fromJson(datos);
    }

    String mensaje;
    if (respuesta.statusCode == 409) {
      mensaje = 'Ese correo ya tiene una cuenta';
    } else if (respuesta.statusCode == 400) {
      try {
        final datos = jsonDecode(respuesta.body);
        if (datos is Map && datos['message'] != null) {
          if (datos['message'] is List) {
            mensaje = datos['message'].first?.toString() ?? 'Datos inválidos';
          } else {
            mensaje = datos['message'].toString();
          }
        } else {
          mensaje = 'Datos inválidos';
        }
      } catch (_) {
        mensaje = 'Datos inválidos';
      }
    } else if (respuesta.statusCode >= 500) {
      mensaje = 'La API no está disponible. Intenta más tarde.';
    } else {
      mensaje = 'No se pudo crear la cuenta.';
    }
    throw ApiException(respuesta.statusCode, mensaje);
  }
}
