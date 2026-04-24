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
