import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GoogleDriveFile {
  final String id;
  final String name;
  final String mimeType;

  const GoogleDriveFile({
    required this.id,
    required this.name,
    required this.mimeType,
  });

  factory GoogleDriveFile.fromMap(Map<String, dynamic> map) {
    return GoogleDriveFile(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      mimeType: (map['mimeType'] ?? '') as String,
    );
  }
}

typedef GoogleAuthHeadersLoader = Future<Map<String, String>> Function();

class GoogleDriveService {
  final String accessToken;
  final GoogleAuthHeadersLoader? authHeadersLoader;

  const GoogleDriveService({
    this.accessToken = '',
    this.authHeadersLoader,
  });

  Future<Map<String, String>> _headers() async {
    if (authHeadersLoader != null) {
      final Map<String, String> headers = await authHeadersLoader!.call();
      if ((headers['Authorization'] ?? headers['authorization'] ?? '')
          .trim()
          .isNotEmpty) {
        return headers;
      }
    }

    if (accessToken.trim().isEmpty) {
      throw Exception('Token Google Drive assente.');
    }

    return <String, String>{
      'Authorization': 'Bearer ${accessToken.trim()}',
    };
  }

  Future<List<GoogleDriveFile>> listPdfFiles(String folderId) async {
    final String query =
        "'$folderId' in parents and trashed = false and mimeType = 'application/pdf'";

    final Uri url = Uri.https(
      'www.googleapis.com',
      '/drive/v3/files',
      <String, String>{
        'q': query,
        'fields': 'files(id,name,mimeType)',
        'orderBy': 'createdTime desc',
        'pageSize': '100',
      },
    );

    final http.Response response = await http.get(
      url,
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Errore Google Drive API: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> rawFiles =
        data['files'] as List<dynamic>? ?? <dynamic>[];

    return rawFiles
        .map(
          (dynamic item) => GoogleDriveFile.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  static String buildFileViewUrl(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/view';
  }

  Future<Uint8List> downloadPdfBytes(String fileId) async {
    final Uri url =
        Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId?alt=media');

    final http.Response response = await http.get(
      url,
      headers: await _headers(),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Errore download PDF Drive: ${response.statusCode} ${response.body}',
      );
    }

    return response.bodyBytes;
  }

  Future<String> uploadPdfBytes({
    required String fileName,
    required Uint8List bytes,
    required String parentFolderId,
  }) {
    return uploadFileBytes(
      fileName: fileName,
      bytes: bytes,
      parentFolderId: parentFolderId,
      mimeType: 'application/pdf',
    );
  }

  Future<String> uploadFileBytes({
    required String fileName,
    required Uint8List bytes,
    required String parentFolderId,
    required String mimeType,
  }) async {
    final String boundary = 'phbox_upload_boundary';
    final Uri url = Uri.parse(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
    );

    final Map<String, dynamic> metadata = <String, dynamic>{
      'name': fileName,
      'parents': <String>[parentFolderId],
      'mimeType': mimeType,
    };

    final List<int> body = <int>[]
      ..addAll(utf8.encode('--$boundary\r\n'))
      ..addAll(
        utf8.encode('Content-Type: application/json; charset=UTF-8\r\n\r\n'),
      )
      ..addAll(utf8.encode(jsonEncode(metadata)))
      ..addAll(utf8.encode('\r\n--$boundary\r\n'))
      ..addAll(utf8.encode('Content-Type: $mimeType\r\n\r\n'))
      ..addAll(bytes)
      ..addAll(utf8.encode('\r\n--$boundary--'));

    final Map<String, String> headers = await _headers();
    final http.Response response = await http.post(
      url,
      headers: <String, String>{
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Errore upload file Drive: ${response.statusCode} ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final String fileId = (data['id'] ?? '') as String;
    if (fileId.isEmpty) {
      throw Exception('Upload Drive completato ma fileId assente.');
    }
    return fileId;
  }
}
