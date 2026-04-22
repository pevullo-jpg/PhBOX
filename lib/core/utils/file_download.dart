import 'dart:typed_data';

import 'file_download_stub.dart' if (dart.library.html) 'file_download_web.dart' as impl;

Future<void> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json;charset=utf-8',
}) {
  return impl.downloadTextFile(
    filename: filename,
    content: content,
    mimeType: mimeType,
  );
}

Future<void> downloadBinaryFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) {
  return impl.downloadBinaryFile(
    filename: filename,
    bytes: bytes,
    mimeType: mimeType,
  );
}
