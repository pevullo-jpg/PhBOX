class AppSettings {
  final String googleWebClientId;
  final String connectedGoogleEmail;
  final String connectedGoogleDisplayName;
  final String incomingPdfDriveFolderId;
  final String incomingImageDriveFolderId;
  final String processedDriveFolderId;
  final String mergedPdfDriveFolderId;
  final bool autoScanEnabled;
  final bool autoMergeByPatient;
  final bool autoDetectDpc;
  final List<String> acceptedExtensions;
  final int expiryWarningDays;
  final int scanIntervalMinutes;
  final bool emailScanEnabled;
  final bool emailTrashProcessedMessages;
  final String emailProcessedLabel;
  final String emailIgnoredLabel;
  final String emailScanQuery;
  final int emailMaxResults;
  final List<String> doctorsCatalog;
  final DateTime updatedAt;

  const AppSettings({
    this.googleWebClientId = '',
    this.connectedGoogleEmail = '',
    this.connectedGoogleDisplayName = '',
    this.incomingPdfDriveFolderId = '',
    this.incomingImageDriveFolderId = '',
    this.processedDriveFolderId = '',
    this.mergedPdfDriveFolderId = '',
    this.autoScanEnabled = false,
    this.autoMergeByPatient = true,
    this.autoDetectDpc = true,
    this.acceptedExtensions = const <String>['pdf', 'jpg', 'png'],
    this.expiryWarningDays = 7,
    this.scanIntervalMinutes = 30,
    this.emailScanEnabled = false,
    this.emailTrashProcessedMessages = true,
    this.emailProcessedLabel = 'PhBOX Processed',
    this.emailIgnoredLabel = 'PhBOX Ignored',
    this.emailScanQuery = 'in:inbox has:attachment',
    this.emailMaxResults = 25,
    this.doctorsCatalog = const <String>[],
    required this.updatedAt,
  });

  AppSettings copyWith({
    String? googleWebClientId,
    String? connectedGoogleEmail,
    String? connectedGoogleDisplayName,
    String? incomingPdfDriveFolderId,
    String? incomingImageDriveFolderId,
    String? processedDriveFolderId,
    String? mergedPdfDriveFolderId,
    bool? autoScanEnabled,
    bool? autoMergeByPatient,
    bool? autoDetectDpc,
    List<String>? acceptedExtensions,
    int? expiryWarningDays,
    int? scanIntervalMinutes,
    bool? emailScanEnabled,
    bool? emailTrashProcessedMessages,
    String? emailProcessedLabel,
    String? emailIgnoredLabel,
    String? emailScanQuery,
    int? emailMaxResults,
    List<String>? doctorsCatalog,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      googleWebClientId: googleWebClientId ?? this.googleWebClientId,
      connectedGoogleEmail: connectedGoogleEmail ?? this.connectedGoogleEmail,
      connectedGoogleDisplayName:
          connectedGoogleDisplayName ?? this.connectedGoogleDisplayName,
      incomingPdfDriveFolderId:
          incomingPdfDriveFolderId ?? this.incomingPdfDriveFolderId,
      incomingImageDriveFolderId:
          incomingImageDriveFolderId ?? this.incomingImageDriveFolderId,
      processedDriveFolderId:
          processedDriveFolderId ?? this.processedDriveFolderId,
      mergedPdfDriveFolderId:
          mergedPdfDriveFolderId ?? this.mergedPdfDriveFolderId,
      autoScanEnabled: autoScanEnabled ?? this.autoScanEnabled,
      autoMergeByPatient: autoMergeByPatient ?? this.autoMergeByPatient,
      autoDetectDpc: autoDetectDpc ?? this.autoDetectDpc,
      acceptedExtensions: acceptedExtensions ?? this.acceptedExtensions,
      expiryWarningDays: expiryWarningDays ?? this.expiryWarningDays,
      scanIntervalMinutes: scanIntervalMinutes ?? this.scanIntervalMinutes,
      emailScanEnabled: emailScanEnabled ?? this.emailScanEnabled,
      emailTrashProcessedMessages:
          emailTrashProcessedMessages ?? this.emailTrashProcessedMessages,
      emailProcessedLabel: emailProcessedLabel ?? this.emailProcessedLabel,
      emailIgnoredLabel: emailIgnoredLabel ?? this.emailIgnoredLabel,
      emailScanQuery: emailScanQuery ?? this.emailScanQuery,
      emailMaxResults: emailMaxResults ?? this.emailMaxResults,
      doctorsCatalog: doctorsCatalog ?? this.doctorsCatalog,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'googleWebClientId': googleWebClientId,
      'connectedGoogleEmail': connectedGoogleEmail,
      'connectedGoogleDisplayName': connectedGoogleDisplayName,
      'incomingPdfDriveFolderId': incomingPdfDriveFolderId,
      'incomingImageDriveFolderId': incomingImageDriveFolderId,
      'processedDriveFolderId': processedDriveFolderId,
      'mergedPdfDriveFolderId': mergedPdfDriveFolderId,
      'autoScanEnabled': autoScanEnabled,
      'autoMergeByPatient': autoMergeByPatient,
      'autoDetectDpc': autoDetectDpc,
      'acceptedExtensions': acceptedExtensions,
      'expiryWarningDays': expiryWarningDays,
      'scanIntervalMinutes': scanIntervalMinutes,
      'emailScanEnabled': emailScanEnabled,
      'emailTrashProcessedMessages': emailTrashProcessedMessages,
      'emailProcessedLabel': emailProcessedLabel,
      'emailIgnoredLabel': emailIgnoredLabel,
      'emailScanQuery': emailScanQuery,
      'emailMaxResults': emailMaxResults,
      'doctorsCatalog': doctorsCatalog,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      googleWebClientId: (map['googleWebClientId'] ?? '') as String,
      connectedGoogleEmail: (map['connectedGoogleEmail'] ?? '') as String,
      connectedGoogleDisplayName:
          (map['connectedGoogleDisplayName'] ?? '') as String,
      incomingPdfDriveFolderId:
          (map['incomingPdfDriveFolderId'] ?? map['incomingDriveFolderId'] ?? '')
              as String,
      incomingImageDriveFolderId:
          (map['incomingImageDriveFolderId'] ?? '') as String,
      processedDriveFolderId: (map['processedDriveFolderId'] ?? '') as String,
      mergedPdfDriveFolderId: (map['mergedPdfDriveFolderId'] ?? '') as String,
      autoScanEnabled: (map['autoScanEnabled'] ?? false) as bool,
      autoMergeByPatient: (map['autoMergeByPatient'] ?? true) as bool,
      autoDetectDpc: (map['autoDetectDpc'] ?? true) as bool,
      acceptedExtensions: List<String>.from(
        map['acceptedExtensions'] ?? const <String>['pdf', 'jpg', 'png'],
      ),
      expiryWarningDays: (map['expiryWarningDays'] ?? 7) as int,
      scanIntervalMinutes: (map['scanIntervalMinutes'] ?? 30) as int,
      emailScanEnabled: (map['emailScanEnabled'] ?? false) as bool,
      emailTrashProcessedMessages:
          (map['emailTrashProcessedMessages'] ?? true) as bool,
      emailProcessedLabel:
          (map['emailProcessedLabel'] ?? 'PhBOX Processed') as String,
      emailIgnoredLabel:
          (map['emailIgnoredLabel'] ?? 'PhBOX Ignored') as String,
      emailScanQuery:
          (map['emailScanQuery'] ?? 'in:inbox has:attachment') as String,
      emailMaxResults: (map['emailMaxResults'] ?? 25) as int,
      doctorsCatalog: List<String>.from(map['doctorsCatalog'] ?? const <String>[]),
      updatedAt: _readDate(map['updatedAt']) ?? DateTime.now(),
    );
  }

  factory AppSettings.empty() {
    return AppSettings(updatedAt: DateTime.now());
  }

  static DateTime? _readDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    try {
      final dynamic date = (value as dynamic).toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    try {
      final dynamic seconds = (value as dynamic).seconds;
      if (seconds is int) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }
}
