Future<void> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json;charset=utf-8',
}) async {
  throw UnsupportedError('Download file supportato solo sul web.');
}
