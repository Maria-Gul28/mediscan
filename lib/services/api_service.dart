import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/medicine.dart';

/// Free hosts sleep when idle; the first request can take ~30-60s to wake it.
const _timeout = Duration(seconds: 90);

/// All calls to the MediScan backend. Every scan/lookup is a live call - no
/// local database, no caching - so expect each identify call to take a few
/// seconds.
class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'MEDISCAN_API_BASE',
    defaultValue: 'https://mediscan-api.onrender.com', // <- your Render URL
  );

  /// Sends the photographed pack for identification - reads printed text
  /// when legible, falls back to visual recognition (pack color/shape/
  /// design) when it isn't.
  Future<Medicine> identifyImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _guessMimeType(imageFile.path);

    final uri = Uri.parse('$baseUrl/api/medicines/identify');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body:
              jsonEncode({'image_base64': base64Image, 'mime_type': mimeType}),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw ApiException(
          'Identification failed (${res.statusCode}): ${res.body}');
    }
    return Medicine.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Sends a transcribed medicine name (from voice input or typed text) for
  /// identification.
  Future<Medicine> identifyByName(String name) async {
    final uri = Uri.parse('$baseUrl/api/medicines/identify-by-name');
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name}),
        )
        .timeout(_timeout);

    if (res.statusCode != 200) {
      throw ApiException(
          'Identification failed (${res.statusCode}): ${res.body}');
    }
    return Medicine.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Sends a follow-up question to the chat, grounded in [medicine] - passed
  /// in directly since there's no database to fetch it from.
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
    if (res.statusCode != 200) {
      throw ApiException('Chat failed (${res.statusCode})');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['reply'] as String;
  }

  /// Asks the backend to speak [text] and returns MP3 bytes. This is what
  /// makes Urdu audio work on phones that have no Urdu voice installed.
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
      throw ApiException('Speech failed (${res.statusCode})');
    }
    return res.bodyBytes;
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
