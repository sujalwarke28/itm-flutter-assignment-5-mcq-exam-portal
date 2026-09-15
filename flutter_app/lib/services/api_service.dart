import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../utils/app_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Thin REST client shared by every feature service. Centralizes auth-header
/// injection and error handling so callers only deal with decoded JSON.
class ApiService {
  final http.Client _client;
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  dynamic _decode(http.Response res) {
    final body = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final message = (body is Map && body['error'] != null) ? body['error'].toString() : 'Request failed';
    throw ApiException(message, statusCode: res.statusCode);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await _client.get(_uri(path, query), headers: await _headers(json: false));
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await _client.post(_uri(path), headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    return _decode(res);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final res = await _client.put(_uri(path), headers: await _headers(), body: body != null ? jsonEncode(body) : null);
    return _decode(res);
  }

  Future<dynamic> delete(String path) async {
    final res = await _client.delete(_uri(path), headers: await _headers(json: false));
    return _decode(res);
  }

  Future<dynamic> postMultipart(
    String path, {
    required String fileField,
    required String filePath,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(await _headers(json: false))
      ..fields.addAll(fields ?? {})
      ..files.add(await http.MultipartFile.fromPath(fileField, filePath));

    final streamed = await _client.send(request);
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }
}
