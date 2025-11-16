import 'dart:convert';
import 'package:http/http.dart' as http;

/*

  ApiClient

*/
class ApiClient 
{
  ApiClient._internal();
  static final ApiClient instance = ApiClient._internal(); // singleton

  // runtime persistant client for connecting to the server
  final http.Client _client = http.Client();

  // for android virtual device
  String baseUrl = 'http://10.0.2.2:8080';

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<http.Response> get(String path, {Map<String, String>? headers}) 
  {
    return _client.get
    (
      _uri(path),
      headers: headers
    );
  }

  Future<http.Response> postJson
  (
    String path, 
    Map<String, dynamic> jsonBody,
    {Map<String, String>? headers}
  ) 
  {
    final finalHeaders = <String, String>
    {
      'Content-Type': 'application/json',
      if (headers != null) ...headers
    };

    return _client.post(
      _uri(path),
      headers: finalHeaders,
      body: jsonEncode(jsonBody),
    );
  }

  Future<http.Response> putJson
  (
    String path,
    Map<String, dynamic> jsonBody,
    {Map<String, String>? headers}
  ) 
  {
    final finalHeaders = <String, String>
    {
      'Content-Type': 'application/json',
      if (headers != null) ...headers
    };

    return _client.put(
      _uri(path),
      headers: finalHeaders,
      body: jsonEncode(jsonBody),
    );
  }

  Future<http.Response> delete
  (
    String path,
   {Map<String, String>? headers}
  ) 
  {
    return _client.delete(
      _uri(path),
      headers: headers
    );
  }
}