import 'dart:typed_data';

Future<void> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json;charset=utf-8',
}) async {
  throw UnsupportedError('Download file supportato solo sul web.');
}

Future<void> downloadBinaryFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  throw UnsupportedError('Download file supportato solo sul web.');
}
