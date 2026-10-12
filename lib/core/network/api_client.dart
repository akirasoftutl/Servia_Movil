import 'package:http/http.dart' as http;

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.1.7:3000',
  );

  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<http.Response> get(String endpoint, {String? token}) {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    return _client.get(url, headers: headers);
  }
}