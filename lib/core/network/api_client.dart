import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.1.19:3000',
  );

  static const Duration tiempoLimite = Duration(seconds: 15);

  final http.Client _client;
  final Duration limite;

  ApiClient({http.Client? client, this.limite = tiempoLimite})
    : _client = client ?? http.Client();

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
}
