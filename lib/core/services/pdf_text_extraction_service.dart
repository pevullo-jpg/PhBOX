import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfTextExtractionService {
  const PdfTextExtractionService();

  String extractText(Uint8List bytes) {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    try {
      final PdfTextExtractor extractor = PdfTextExtractor(document);
      final String text = extractor.extractText();
      return text.trim();
    } finally {
      document.dispose();
    }
  }
}
