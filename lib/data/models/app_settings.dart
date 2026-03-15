class AppSettings {
  final String incomingDriveFolderId;
  final String processedDriveFolderId;
  final String mergedPdfDriveFolderId;
  final DateTime updatedAt;

  const AppSettings({
    this.incomingDriveFolderId = '',
    this.processedDriveFolderId = '',
    this.mergedPdfDriveFolderId = '',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'incomingDriveFolderId': incomingDriveFolderId,
      'processedDriveFolderId': processedDriveFolderId,
      'mergedPdfDriveFolderId': mergedPdfDriveFolderId,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.empty() {
    return AppSettings(updatedAt: DateTime.now());
  }
}