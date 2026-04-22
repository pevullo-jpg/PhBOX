import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> downloadTextFile({
  required String filename,
  required String content,
  String mimeType = 'application/json;charset=utf-8',
}) async {
  final List<int> bytes = utf8.encode(content);
  final html.Blob blob = html.Blob(<dynamic>[bytes], mimeType);
  final String url = html.Url.createObjectUrlFromBlob(blob);
  final html.AnchorElement anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

Future<void> downloadBinaryFile({
  required String filename,
  required Uint8List bytes,
  required String mimeType,
}) async {
  final html.Blob blob = html.Blob(<dynamic>[bytes], mimeType);
  final String url = html.Url.createObjectUrlFromBlob(blob);
  final html.AnchorElement anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
