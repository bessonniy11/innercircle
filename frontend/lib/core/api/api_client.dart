import 'package:dio/dio.dart';
import 'dart:convert'; // Add this import

class ApiClient {
  late Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:3000', // TODO: Replace with your backend URL
        connectTimeout: const Duration(milliseconds: 5000), // 5 seconds
        receiveTimeout: const Duration(milliseconds: 3000), // 3 seconds
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  Dio get dio => _dio;

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void removeAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  // Helper to decode JWT token and extract payload
  Map<String, dynamic> decodeJwtToken(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid JWT token format');
    }
    final payload = _decodeBase64(parts[1]);
    final Map<String, dynamic> jsonPayload = json.decode(payload);
    return jsonPayload;
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!');
    }
    return utf8.decode(base64Url.decode(output));
  }
} 