import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.1.19:3000',
  );

  static const Duration tiempoLimite = Duration(seconds: 15);

  /// Una foto de hasta 5 MB tarda más que una consulta en una red lenta.
  static const Duration tiempoLimiteSubida = Duration(seconds: 60);

  final http.Client _client;
  final Duration limite;
  final Duration limiteSubida;

  ApiClient({
    http.Client? client,
    this.limite = tiempoLimite,
    this.limiteSubida = tiempoLimiteSubida,
  }) : _client = client ?? http.Client();

  Future<http.Response> get(String endpoint, {String? token}) {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return _client.get(url, headers: headers).timeout(limite);
  }

  Future<http.Response> post(
    String endpoint, {
    String? token,
    String? body,
    Map<String, String>? headers,
  }) {
    final url = Uri.parse('$baseUrl$endpoint');
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    if (headers != null) {
      requestHeaders.addAll(headers);
    }
    return _client
        .post(url, headers: requestHeaders, body: body)
        .timeout(limite);
  }

  Future<http.Response> patch(String endpoint, {String? token, String? body}) {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return _client.patch(url, headers: headers, body: body).timeout(limite);
  }

  /// `PUT`; sin [body] no manda `Content-Type` (por ejemplo, favoritos).
  Future<http.Response> put(String endpoint, {String? token, String? body}) {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return _client.put(url, headers: headers, body: body).timeout(limite);
  }

  /// Usado para dar de baja el token FCM al cerrar sesión (MVP-28).
  Future<http.Response> delete(
    String endpoint, {
    String? token,
    String? body,
  }) {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return _client.delete(url, headers: headers, body: body).timeout(limite);
  }

  /// `POST` multipart con un solo archivo en el campo [campo] (por ejemplo,
  /// la foto de perfil). No declara el tipo del archivo: la API lo valida por
  /// sus bytes.
  Future<http.Response> postArchivo(
    String endpoint, {
    String? token,
    required String campo,
    required List<int> bytes,
    required String nombre,
  }) async {
    final peticion =
        http.MultipartRequest('POST', Uri.parse('$baseUrl$endpoint'))
          ..headers['Accept'] = 'application/json'
          ..files.add(
            http.MultipartFile.fromBytes(campo, bytes, filename: nombre),
          );
    if (token != null) peticion.headers['Authorization'] = 'Bearer $token';
    return http.Response.fromStream(await _client.send(peticion))
        .timeout(limiteSubida);
  }
}
