import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? status;
  final bool offline;

  ApiException(this.message, {this.status, this.offline = false});

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

class ApiClient {
  final String baseUrl;
  String? token;

  ApiClient({required this.baseUrl});

  final http.Client _client = http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> get(String path, {Duration timeout = const Duration(seconds: 25)}) =>
      _send('GET', path, timeout: timeout);

  Future<dynamic> post(String path, Map<String, dynamic> body,
          {Duration timeout = const Duration(seconds: 25)}) =>
      _send('POST', path, body: body, timeout: timeout);

  Future<dynamic> put(String path, Map<String, dynamic> body,
          {Duration timeout = const Duration(seconds: 25)}) =>
      _send('PUT', path, body: body, timeout: timeout);

  Future<dynamic> delete(String path, {Duration timeout = const Duration(seconds: 25)}) =>
      _send('DELETE', path, timeout: timeout);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    final currentToken = token;
    if (currentToken != null && currentToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $currentToken';
    }

    try {
      final uri = _uri(path);
      late http.Response response;
      switch (method) {
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(timeout);
          break;
        default:
          response = await _client.get(uri, headers: headers).timeout(timeout);
      }

      dynamic data;
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = null;
        }
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return data;
      }

      final message = (data is Map && data['error'] != null)
          ? data['error'].toString()
          : 'Error ${response.statusCode}';
      throw ApiException(message, status: response.statusCode);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('El servidor tardó demasiado. Se guardará para sincronizar.',
          offline: true);
    } on SocketException {
      throw ApiException('Sin conexión con el servidor.', offline: true);
    } on http.ClientException {
      throw ApiException('Sin conexión con el servidor.', offline: true);
    } on FormatException {
      throw ApiException('Respuesta no válida del servidor.', offline: true);
    } catch (e) {
      throw ApiException('No se pudo conectar: $e', offline: true);
    }
  }

  Future<bool> health({Duration timeout = const Duration(seconds: 7)}) async {
    try {
      final result = await get('/api/health', timeout: timeout);
      return result is Map && result['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
