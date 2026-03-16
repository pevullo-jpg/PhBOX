import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GmailAttachmentRef {
  final String attachmentId;
  final String filename;
  final String mimeType;
  final String partId;
  final int size;
  final String inlineData;

  const GmailAttachmentRef({
    required this.attachmentId,
    required this.filename,
    required this.mimeType,
    required this.partId,
    required this.size,
    this.inlineData = '',
  });
}

class GmailMessageDetail {
  final String id;
  final String threadId;
  final String subject;
  final String from;
  final String snippet;
  final List<String> labelIds;
  final List<GmailAttachmentRef> attachments;

  const GmailMessageDetail({
    required this.id,
    required this.threadId,
    required this.subject,
    required this.from,
    required this.snippet,
    required this.labelIds,
    required this.attachments,
  });
}

class GmailService {
  final String accessToken;

  const GmailService({required this.accessToken});

  Future<List<String>> listMessageIds({
    required String query,
    int maxResults = 25,
  }) async {
    final Uri url = Uri.https(
      'gmail.googleapis.com',
      '/gmail/v1/users/me/messages',
      <String, String>{
        'q': query,
        'maxResults': maxResults.toString(),
      },
    );

    final http.Response response = await http.get(url, headers: _headers());
    _ensureOk(response, 'Errore Gmail list messages');

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> messages = data['messages'] as List<dynamic>? ?? <dynamic>[];

    return messages
        .map((dynamic item) => (item as Map<String, dynamic>)['id'] as String? ?? '')
        .where((String item) => item.isNotEmpty)
        .toList();
  }

  Future<GmailMessageDetail> getMessage(String messageId) async {
    final Uri url = Uri.https(
      'gmail.googleapis.com',
      '/gmail/v1/users/me/messages/$messageId',
      <String, String>{'format': 'full'},
    );

    final http.Response response = await http.get(url, headers: _headers());
    _ensureOk(response, 'Errore Gmail read message');

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final Map<String, dynamic> payload =
        Map<String, dynamic>.from(data['payload'] as Map? ?? <String, dynamic>{});
    final List<GmailAttachmentRef> attachments = _extractAttachments(payload);

    return GmailMessageDetail(
      id: (data['id'] ?? '') as String,
      threadId: (data['threadId'] ?? '') as String,
      subject: _readHeader(payload, 'Subject'),
      from: _readHeader(payload, 'From'),
      snippet: (data['snippet'] ?? '') as String,
      labelIds: List<String>.from(data['labelIds'] ?? const <String>[]),
      attachments: attachments,
    );
  }

  Future<Uint8List> downloadAttachment({
    required String messageId,
    required GmailAttachmentRef attachment,
  }) async {
    if (attachment.inlineData.isNotEmpty) {
      return base64Url.decode(base64.normalize(attachment.inlineData));
    }

    final Uri url = Uri.https(
      'gmail.googleapis.com',
      '/gmail/v1/users/me/messages/$messageId/attachments/${attachment.attachmentId}',
    );

    final http.Response response = await http.get(url, headers: _headers());
    _ensureOk(response, 'Errore Gmail download attachment');

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final String encoded = (data['data'] ?? '') as String;
    if (encoded.isEmpty) {
      throw Exception('Attachment Gmail vuoto.');
    }
    return base64Url.decode(base64.normalize(encoded));
  }

  Future<String> ensureLabel(String labelName) async {
    final String trimmed = labelName.trim();
    if (trimmed.isEmpty) {
      throw Exception('Nome etichetta Gmail non valido.');
    }

    final Map<String, String> labels = await listLabels();
    for (final MapEntry<String, String> entry in labels.entries) {
      if (entry.value.toLowerCase() == trimmed.toLowerCase()) {
        return entry.key;
      }
    }

    final Uri url = Uri.https('gmail.googleapis.com', '/gmail/v1/users/me/labels');
    final http.Response response = await http.post(
      url,
      headers: <String, String>{..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'name': trimmed,
        'labelListVisibility': 'labelShow',
        'messageListVisibility': 'show',
      }),
    );
    _ensureOk(response, 'Errore Gmail create label');

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return (data['id'] ?? '') as String;
  }

  Future<Map<String, String>> listLabels() async {
    final Uri url = Uri.https('gmail.googleapis.com', '/gmail/v1/users/me/labels');
    final http.Response response = await http.get(url, headers: _headers());
    _ensureOk(response, 'Errore Gmail labels');

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    final List<dynamic> labels = data['labels'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, String> result = <String, String>{};
    for (final dynamic raw in labels) {
      final Map<String, dynamic> label = Map<String, dynamic>.from(raw as Map);
      final String id = (label['id'] ?? '') as String;
      final String name = (label['name'] ?? '') as String;
      if (id.isNotEmpty && name.isNotEmpty) {
        result[id] = name;
      }
    }
    return result;
  }

  Future<void> modifyMessageLabels({
    required String messageId,
    List<String> addLabelIds = const <String>[],
    List<String> removeLabelIds = const <String>[],
  }) async {
    final Uri url = Uri.https(
      'gmail.googleapis.com',
      '/gmail/v1/users/me/messages/$messageId/modify',
    );

    final http.Response response = await http.post(
      url,
      headers: <String, String>{..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(<String, dynamic>{
        'addLabelIds': addLabelIds,
        'removeLabelIds': removeLabelIds,
      }),
    );
    _ensureOk(response, 'Errore Gmail modify labels');
  }

  Future<void> trashMessage(String messageId) async {
    final Uri url = Uri.https(
      'gmail.googleapis.com',
      '/gmail/v1/users/me/messages/$messageId/trash',
    );
    final http.Response response = await http.post(url, headers: _headers());
    _ensureOk(response, 'Errore Gmail trash message');
  }

  List<GmailAttachmentRef> _extractAttachments(Map<String, dynamic> payload) {
    final List<GmailAttachmentRef> result = <GmailAttachmentRef>[];

    void walk(Map<String, dynamic> part) {
      final String filename = (part['filename'] ?? '') as String;
      final String mimeType = (part['mimeType'] ?? '') as String;
      final Map<String, dynamic> body =
          Map<String, dynamic>.from(part['body'] as Map? ?? <String, dynamic>{});
      final String attachmentId = (body['attachmentId'] ?? '') as String;
      final String inlineData = (body['data'] ?? '') as String;

      if ((attachmentId.isNotEmpty || inlineData.isNotEmpty) && filename.trim().isNotEmpty) {
        result.add(
          GmailAttachmentRef(
            attachmentId: attachmentId,
            filename: filename,
            mimeType: mimeType,
            partId: (part['partId'] ?? '') as String,
            size: (body['size'] ?? 0) as int,
            inlineData: inlineData,
          ),
        );
      }

      final List<dynamic> parts = part['parts'] as List<dynamic>? ?? <dynamic>[];
      for (final dynamic child in parts) {
        walk(Map<String, dynamic>.from(child as Map));
      }
    }

    walk(payload);
    return result;
  }

  String _readHeader(Map<String, dynamic> payload, String name) {
    final List<dynamic> headers = payload['headers'] as List<dynamic>? ?? <dynamic>[];
    for (final dynamic item in headers) {
      final Map<String, dynamic> header = Map<String, dynamic>.from(item as Map);
      final String current = (header['name'] ?? '') as String;
      if (current.toLowerCase() == name.toLowerCase()) {
        return (header['value'] ?? '') as String;
      }
    }
    return '';
  }

  Map<String, String> _headers() {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }

  void _ensureOk(http.Response response, String prefix) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$prefix: ${response.statusCode} ${response.body}');
    }
  }
}
