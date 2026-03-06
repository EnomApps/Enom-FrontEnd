import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://api.enom.ai';
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // --- Token Management ---

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, json.encode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_userKey);
    if (data != null) {
      return json.decode(data) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // --- HTTP Helpers ---

  static Map<String, String> _headers({String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    String? token;
    if (auth) {
      token = await getToken();
    }

    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(token: token),
      body: json.encode(body),
    );

    return {
      'statusCode': response.statusCode,
      'body': json.decode(response.body),
    };
  }

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    bool auth = false,
  }) async {
    String? token;
    if (auth) {
      token = await getToken();
    }

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(token: token),
    );

    return {
      'statusCode': response.statusCode,
      'body': json.decode(response.body),
    };
  }

  static Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    String? filePath,
    String? fileField,
    Uint8List? fileBytes,
    String? fileName,
    bool auth = false,
  }) async {
    String? token;
    if (auth) {
      token = await getToken();
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl$endpoint'),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });

    request.fields.addAll(fields);

    if (fileField != null && fileBytes != null && fileName != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName,
      ));
    } else if (filePath != null && fileField != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return {
      'statusCode': response.statusCode,
      'body': json.decode(response.body),
    };
  }
}
