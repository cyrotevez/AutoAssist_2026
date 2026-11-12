import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

class Api {
  String baseUrl;
  String? token;
  Api(this.baseUrl, this.token);

  static String normalize(String url) {
    var u = url.trim();
    if (u.isEmpty) return u;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final params = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && v.toString().isNotEmpty) params[k] = v.toString();
    });
    final uri = Uri.parse('${normalize(baseUrl)}$path');
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  String wsUrl(String path) {
    final u = normalize(baseUrl);
    final ws = u.startsWith('https://') ? 'wss://${u.substring(8)}' : 'ws://${u.substring(7)}';
    return '$ws$path';
  }

  String _errorText(dynamic data, int code) {
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    if (data is Map && data['detail'] is List) return 'Please check the details you entered and try again.';
    if (code == 401) return 'Please log in again.';
    return 'Something went wrong (code $code).';
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    int timeout = 15,
  }) async {
    final uri = _uri(path, query);
    final limit = Duration(seconds: timeout);
    try {
      http.Response res;
      switch (method) {
        case 'POST':
          res = await http.post(uri, headers: _headers, body: jsonEncode(body ?? {})).timeout(limit);
          break;
        case 'PUT':
          res = await http.put(uri, headers: _headers, body: jsonEncode(body ?? {})).timeout(limit);
          break;
        case 'PATCH':
          res = await http.patch(uri, headers: _headers, body: jsonEncode(body ?? {})).timeout(limit);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: _headers).timeout(limit);
          break;
        default:
          res = await http.get(uri, headers: _headers).timeout(limit);
      }
      final text = utf8.decode(res.bodyBytes);
      dynamic data;
      if (text.isNotEmpty) {
        try {
          data = jsonDecode(text);
        } catch (_) {
          data = null;
        }
      }
      if (res.statusCode >= 200 && res.statusCode < 300) return data;
      throw ApiException(_errorText(data, res.statusCode), res.statusCode);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Check your connection and the server address.');
    } catch (_) {
      throw ApiException('Cannot reach the server. Make sure the backend is running and the server address is correct.');
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query, int timeout = 15}) =>
      _send('GET', path, query: query, timeout: timeout);
  Future<dynamic> post(String path, {Object? body, int timeout = 15}) =>
      _send('POST', path, body: body, timeout: timeout);
  Future<dynamic> put(String path, {Object? body}) => _send('PUT', path, body: body);
  Future<dynamic> patch(String path, {Object? body}) => _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);
}

List<Map<String, dynamic>> asList(dynamic data) {
  if (data is! List) return [];
  return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
}
