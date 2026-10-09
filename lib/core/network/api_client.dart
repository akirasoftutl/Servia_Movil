import 'package:http/http.dart' as http;

class ApiClient {
  
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000/api'
  );

  final http.Client _client = http.Client();

  Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    return await _client.get(url);
  }
}