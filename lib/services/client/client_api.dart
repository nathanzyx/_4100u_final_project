import 'dart:convert';
import 'package:http/http.dart' as http;

/*

  ApiClient

*/
class ApiClient 
{
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal();

  // runtime persistant client for connecting to the server
  final http.Client _client = http.Client();

  String baseUrl = 'http://10.0.2.2:8080';

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<http.Response> get(String path) 
  {
    return _client.get(_uri(path));
  }

  Future<http.Response> postJson(String path, Map<String, dynamic> jsonBody) 
  {
    return _client.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(jsonBody),
    );
  }

  Future<http.Response> putJson(String path, Map<String, dynamic> jsonBody) 
  {
    return _client.put(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(jsonBody),
    );
  }

  Future<http.Response> delete(String path) 
  {
    return _client.delete(_uri(path));
  }
}