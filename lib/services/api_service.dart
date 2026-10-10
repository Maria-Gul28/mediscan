import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/medicine.dart';

const _timeout = Duration(seconds: 90);

/// All calls to the MediScan backend. The API key remains on the backend;
/// never put GROQ_API_KEY in the Flutter app.
class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'MEDISCAN_API_BASE',
    defaultValue: 'https://mediscan-api-rzez.onrender.com',
  );

  Future<Medicine> identifyImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final uri = Uri.parse('$baseUrl/api/medicines/identify');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'image_base64': base64Encode(bytes),
            'mime_type': _guessMimeType(imageFile.path),
          }),
        )
        .timeout(_timeout);
    return Medicine.fromJson(
        _parseJsonObject(res, operation: 'Identification'));
  }

  Future<Medicine> identifyByName(String name) async {
    final uri = Uri.parse('$baseUrl/api/medicines/identify-by-name');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name}),
        )
        .timeout(_timeout);
    return Medicine.fromJson(
        _parseJsonObject(res, operation: 'Identification'));
  }

  Future<String> chat({
    required String message,
    required List<Map<String, String>> history,
    required String lang,
    Medicine? medicine,
  }) async {
    final uri = Uri.parse('$baseUrl/api/chat');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'history': history,
            'lang': lang,
            'medicine': medicine?.toJson(),
          }),
        )
        .timeout(_timeout);
    final body = _parseJsonObject(res, operation: 'Chat');
    final reply = body['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw ApiException(
          'The server returned an empty chat reply. Please try again.');
    }
    return reply;
  }

  Future<Uint8List> synthesizeSpeech(String text,
      {required String lang}) async {
    final uri = Uri.parse('$baseUrl/api/tts');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text, 'lang': lang}),
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      final detail = _errorMessageFromBody(res.body);
      throw ApiException('Speech failed (${res.statusCode}): $detail');
    }
    if (res.bodyBytes.isEmpty) {
      throw ApiException('The server returned empty audio.');
    }
    return res.bodyBytes;
  }

  Map<String, dynamic> _parseJsonObject(
    http.Response response, {
    required String operation,
  }) {
    final body = response.body.trim();
    if (body.isEmpty) {
      throw ApiException(
        '$operation failed: the server returned an empty response '
        '(HTTP ${response.statusCode}). Check the backend deployment logs.',
      );
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw ApiException(
        '$operation failed: the server did not return valid JSON '
        '(HTTP ${response.statusCode}). Check the backend URL and deployment logs.',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException(
          '$operation failed: unexpected server response format.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        '$operation failed (${response.statusCode}): '
        '${decoded['error'] ?? 'Unknown server error'}',
      );
    }
    if (decoded['error'] != null) {
      throw ApiException(decoded['error'].toString());
    }
    return decoded;
  }

  String _errorMessageFromBody(String body) {
    if (body.trim().isEmpty) return 'Empty server response';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return (decoded['error'] ?? 'Unknown server error').toString();
      }
    } catch (_) {
      // Avoid displaying a potentially long HTML/proxy error page.
    }
    return 'Unexpected server response';
  }

  String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
