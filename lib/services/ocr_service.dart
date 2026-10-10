import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Runs on-device OCR against a photographed medicine pack and returns the
/// best-guess medicine name to search for.
///
/// Strategy: ML Kit returns every text block it sees (brand name, dosage mg,
/// batch number, barcode digits, etc). We can't know which block is the
/// brand name for certain, so we:
///   1. Drop blocks that are mostly digits/symbols (batch codes, barcodes).
///   2. Prefer the largest text block by font size (brand names are printed
///      biggest on Pakistani medicine packaging).
///   3. Fall back to the longest alphabetic line if size info is unavailable.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OcrResult> recognizeFromImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognized = await _recognizer.processImage(inputImage);

    final candidates = <_LineCandidate>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (_looksLikeBrandName(text)) {
          final height = (line.boundingBox.bottom - line.boundingBox.top).abs();
          candidates.add(_LineCandidate(text, height));
        }
      }
    }

    if (candidates.isEmpty) {
      return OcrResult(rawText: recognized.text, bestGuess: null);
    }

    candidates.sort((a, b) => b.height.compareTo(a.height));
    return OcrResult(rawText: recognized.text, bestGuess: candidates.first.text);
  }

  bool _looksLikeBrandName(String text) {
    if (text.length < 3) return false;
    final letters = RegExp(r'[A-Za-z]').allMatches(text).length;
    final digits = RegExp(r'[0-9]').allMatches(text).length;
    // Require mostly letters - filters out "500mg", "MFG 03/26", barcodes, etc.
    return letters >= 3 && letters > digits;
  }

  void dispose() => _recognizer.close();
}

class OcrResult {
  final String rawText;
  final String? bestGuess;
  OcrResult({required this.rawText, required this.bestGuess});
}

class _LineCandidate {
  final String text;
  final double height;
  _LineCandidate(this.text, this.height);
}
