import 'dart:convert';
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

class GoogleDriveService {
  final String accessToken;

  const GoogleDriveService({
    required this.accessToken,
  });

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
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Errore Google Drive API: ${response.statusCode} ${response.body}');
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> rawFiles = data['files'] as List<dynamic>? ?? <dynamic>[];

    return rawFiles
        .map(
          (dynamic item) => GoogleDriveFile.fromMap(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }
}
