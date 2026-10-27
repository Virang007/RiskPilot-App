import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrTextService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Process an image from file path and extract recognized text lines
  Future<List<String>> extractTextLines(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      final List<String> lines = [];
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final trimmed = line.text.trim();
          if (trimmed.isNotEmpty) {
            lines.add(trimmed);
          }
        }
      }
      return lines;
    } catch (e) {
      return [];
    }
  }

  /// Close recognizer resources when not needed
  void dispose() {
    _textRecognizer.close();
  }
}
