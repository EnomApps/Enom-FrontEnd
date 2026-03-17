import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://47.129.5.68';
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

    dynamic decoded;
    try {
      decoded = json.decode(response.body);
    } catch (_) {
      decoded = {'message': 'Server error. Please try again later.'};
    }

    return {
      'statusCode': response.statusCode,
      'body': decoded,
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

    dynamic decoded;
    try {
      decoded = json.decode(response.body);
    } catch (_) {
      decoded = {'message': 'Server error. Please try again later.'};
    }

    return {
      'statusCode': response.statusCode,
      'body': decoded,
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
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = switch (ext) {
        'png' => MediaType('image', 'png'),
        'gif' => MediaType('image', 'gif'),
        'webp' => MediaType('image', 'webp'),
        _ => MediaType('image', 'jpeg'),
      };
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName,
        contentType: mimeType,
      ));
    } else if (filePath != null && fileField != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, filePath));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // Debug: log response for troubleshooting
    // ignore: avoid_print
    print('[API] postMultipart $endpoint => ${response.statusCode}: ${response.body}');

    dynamic decoded;
    try {
      decoded = json.decode(response.body);
    } catch (_) {
      decoded = {'message': 'Server error. Please try again later.'};
    }

    return {
      'statusCode': response.statusCode,
      'body': decoded,
    };
  }

  /// Multipart POST with multiple files (e.g. media[] for posts).
  static Future<Map<String, dynamic>> postMultipartMultiFile(
    String endpoint, {
    required Map<String, String> fields,
    required String fileField,
    List<Uint8List>? filesBytes,
    List<String>? fileNames,
    List<String>? filePaths,
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

    // Attach files from bytes
    if (filesBytes != null && fileNames != null) {
      for (int i = 0; i < filesBytes.length; i++) {
        final name = fileNames[i];
        final ext = name.split('.').last.toLowerCase();
        final mimeType = switch (ext) {
          'png' => MediaType('image', 'png'),
          'gif' => MediaType('image', 'gif'),
          'webp' => MediaType('image', 'webp'),
          'mp4' => MediaType('video', 'mp4'),
          'mov' => MediaType('video', 'quicktime'),
          'avi' => MediaType('video', 'x-msvideo'),
          _ => MediaType('image', 'jpeg'),
        };
        request.files.add(http.MultipartFile.fromBytes(
          '$fileField[]',
          filesBytes[i],
          filename: name,
          contentType: mimeType,
        ));
      }
    }

    // Attach files from paths
    if (filePaths != null) {
      for (int i = 0; i < filePaths.length; i++) {
        request.files.add(await http.MultipartFile.fromPath(
          '$fileField[]',
          filePaths[i],
        ));
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    dynamic decoded;
    try {
      decoded = json.decode(response.body);
    } catch (_) {
      decoded = {'message': 'Server error. Please try again later.'};
    }

    return {
      'statusCode': response.statusCode,
      'body': decoded,
    };
  }

  /// HTTP DELETE request
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    bool auth = false,
  }) async {
    String? token;
    if (auth) {
      token = await getToken();
    }

    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: _headers(token: token),
    );

    dynamic decoded;
    try {
      decoded = json.decode(response.body);
    } catch (_) {
      decoded = {'message': 'Server error. Please try again later.'};
    }

    return {
      'statusCode': response.statusCode,
      'body': decoded,
    };
  }
}
