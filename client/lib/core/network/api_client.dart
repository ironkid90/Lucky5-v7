import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;

import "../config/app_config.dart";

class ApiClient {
  ApiClient(this._config);

  final AppConfig _config;

  Future<Map<String, dynamic>> get(
    String path, {
    String? accessToken,
  }) async {
    final uri = Uri.parse("${_config.apiBaseUrl}$path");
    try {
      final response = await http
          .get(uri, headers: _headers(accessToken))
          .timeout(_config.requestTimeout);
      return _decode(response);
    } on SocketException {
      throw StateError(
          "Cannot reach server at ${_config.apiBaseUrl}. Is the API running?");
    } on http.ClientException {
      throw StateError("Network error contacting ${_config.apiBaseUrl}.");
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final uri = Uri.parse("${_config.apiBaseUrl}$path");
    try {
      final response = await http
          .post(
            uri,
            headers: _headers(accessToken),
            body: jsonEncode(body ?? const <String, dynamic>{}),
          )
          .timeout(_config.requestTimeout);
      return _decode(response);
    } on SocketException {
      throw StateError(
          "Cannot reach server at ${_config.apiBaseUrl}. Is the API running?");
    } on http.ClientException {
      throw StateError("Network error contacting ${_config.apiBaseUrl}.");
    }
  }

  Map<String, String> _headers(String? accessToken) {
    final headers = <String, String>{
      "Content-Type": "application/json",
      "Accept": "application/json",
    };
    if (accessToken != null && accessToken.isNotEmpty) {
      headers["Authorization"] = "Bearer $accessToken";
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        final message = payload["message"]?.toString() ??
            "Request failed (${response.statusCode})";
        throw StateError(message);
      }
      return payload;
    } on FormatException {
      throw StateError(
          "Server returned non-JSON response (${response.statusCode}).");
    }
  }
}
