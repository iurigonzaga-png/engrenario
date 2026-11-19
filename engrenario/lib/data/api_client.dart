import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();

  static final _http = http.Client();

  static Uri _uri(String path) => Uri.parse('${ConfigApi.urlBase}$path');

  static Future<List<Map<String, dynamic>>> getList(String path) async {
    final response = await _http.get(_uri(path));
    final body = _decode(response);
    if (body is! List) {
      throw const ApiException('A API retornou uma lista inválida.');
    }
    return body.map((item) {
      if (item is! Map) {
        throw const ApiException('A API retornou um item inválido.');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  static Future<Map<String, dynamic>> getObject(String path) async {
    final response = await _http.get(_uri(path));
    final body = _decode(response);
    if (body is! Map) {
      throw const ApiException('A API retornou um objeto inválido.');
    }
    return Map<String, dynamic>.from(body);
  }

  static Future<Map<String, dynamic>> post(
    String path,
    Map<String, Object?> data,
  ) async {
    final response = await _http.post(
      _uri(path),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(data),
    );
    final body = _decode(response);
    if (body is! Map) {
      throw const ApiException('A API retornou um objeto inválido.');
    }
    return Map<String, dynamic>.from(body);
  }

  static Future<void> put(
    String path,
    Map<String, Object?> data,
  ) async {
    final response = await _http.put(
      _uri(path),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(data),
    );
    _decode(response);
  }

  static Future<void> delete(String path) async {
    final response = await _http.delete(_uri(path));
    _decode(response);
  }

  static dynamic _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'A API respondeu com status ${response.statusCode}.';
      try {
        final body = jsonDecode(response.body);
        if (body is Map && body['error'] is String) {
          message = body['error'] as String;
        }
      } on FormatException {
        if (response.body.isNotEmpty) message = response.body;
      }
      throw ApiException(message);
    }
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw const ApiException('A API retornou uma resposta JSON inválida.');
    }
  }
}
