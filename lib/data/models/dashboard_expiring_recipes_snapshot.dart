class DashboardExpiringRecipesSnapshot {
  final int schemaVersion;
  final int itemCount;
  final int totalExpiringCount;
  final String expiringRecipesSignature;
  final int limit;
  final bool truncated;
  final List<DashboardExpiringRecipe> items;
  final DateTime? updatedAt;

  const DashboardExpiringRecipesSnapshot({
    required this.schemaVersion,
    required this.itemCount,
    required this.totalExpiringCount,
    required this.expiringRecipesSignature,
    required this.limit,
    required this.truncated,
    required this.items,
    this.updatedAt,
  });

  factory DashboardExpiringRecipesSnapshot.empty() {
    return const DashboardExpiringRecipesSnapshot(
      schemaVersion: 1,
      itemCount: 0,
      totalExpiringCount: 0,
      expiringRecipesSignature: '',
      limit: 0,
      truncated: false,
      items: <DashboardExpiringRecipe>[],
    );
  }

  factory DashboardExpiringRecipesSnapshot.fromMap(Map<String, dynamic> map) {
    final List<DashboardExpiringRecipe> items = _readRecipeList(map['items']);
    return DashboardExpiringRecipesSnapshot(
      schemaVersion: _readInt(map['schemaVersion']) ?? 1,
      itemCount: _readInt(map['itemCount']) ?? items.length,
      totalExpiringCount: _readInt(map['totalExpiringCount']) ?? items.length,
      expiringRecipesSignature: _readString(map['expiringRecipesSignature'] ?? map['signature'] ?? map['hash']),
      limit: _readInt(map['limit']) ?? items.length,
      truncated: _readBool(map['truncated']),
      items: items,
      updatedAt: _readDate(map['updatedAt'] ?? map['generatedAt']),
    );
  }

  static String _readString(dynamic value) => value == null ? '' : value.toString().trim();

  static List<DashboardExpiringRecipe> _readRecipeList(dynamic value) {
    if (value is! List) {
      return const <DashboardExpiringRecipe>[];
    }
    return value
        .whereType<Map>()
        .map((Map item) => DashboardExpiringRecipe.fromMap(Map<String, dynamic>.from(item)))
        .where((DashboardExpiringRecipe item) => item.importId.trim().isNotEmpty)
        .toList();
  }
}

class DashboardExpiringRecipe {
  final String id;
  final String importId;
  final String driveFileId;
  final String fileName;
  final String patientFiscalCode;
  final String patientFullName;
  final String doctorFullName;
  final String exemptionCode;
  final String city;
  final List<String> therapy;
  final bool isDpc;
  final int prescriptionCount;
  final DateTime? prescriptionDate;
  final DateTime? expiryDate;
  final int daysToExpiry;
  final String webViewLink;
  final String openUrl;
  final String sourceType;
  final String status;
  final DateTime? updatedAt;

  const DashboardExpiringRecipe({
    required this.id,
    required this.importId,
    required this.driveFileId,
    required this.fileName,
    required this.patientFiscalCode,
    required this.patientFullName,
    required this.doctorFullName,
    required this.exemptionCode,
    required this.city,
    required this.therapy,
    required this.isDpc,
    required this.prescriptionCount,
    this.prescriptionDate,
    this.expiryDate,
    required this.daysToExpiry,
    required this.webViewLink,
    required this.openUrl,
    required this.sourceType,
    required this.status,
    this.updatedAt,
  });

  factory DashboardExpiringRecipe.fromMap(Map<String, dynamic> map) {
    final String importId = _readString(map['importId'] ?? map['id'] ?? map['driveFileId']);
    return DashboardExpiringRecipe(
      id: _readString(map['id']).isEmpty ? importId : _readString(map['id']),
      importId: importId,
      driveFileId: _readString(map['driveFileId'] ?? map['fileId']),
      fileName: _readString(map['fileName']),
      patientFiscalCode: _readString(map['patientFiscalCode'] ?? map['fiscalCode']).toUpperCase(),
      patientFullName: _readString(map['patientFullName'] ?? map['patientName'] ?? map['fullName']),
      doctorFullName: _readString(map['doctorFullName'] ?? map['doctorName']),
      exemptionCode: _readString(map['exemptionCode'] ?? map['exemption']),
      city: _readString(map['city']),
      therapy: _readStringList(map['therapy']),
      isDpc: _readBool(map['isDpc'] ?? map['dpcFlag']),
      prescriptionCount: _readInt(map['prescriptionCount'] ?? map['recipeCount'] ?? map['count']) ?? 1,
      prescriptionDate: _readDate(map['prescriptionDate']),
      expiryDate: _readDate(map['expiryDate']),
      daysToExpiry: _readInt(map['daysToExpiry']) ?? 0,
      webViewLink: _readString(map['webViewLink'] ?? map['viewLink'] ?? map['driveViewLink']),
      openUrl: _readString(map['openUrl']),
      sourceType: _readString(map['sourceType'] ?? map['source']),
      status: _readString(map['status']),
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  String get displayPatient {
    final String name = patientFullName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    final String cf = patientFiscalCode.trim();
    return cf.isEmpty ? 'Assistito' : cf;
  }

  String get effectiveViewLink {
    final String primary = webViewLink.trim();
    if (primary.isNotEmpty) {
      return primary;
    }
    return openUrl.trim();
  }

  bool get isExpired => daysToExpiry < 0;

  String get expiryLabel {
    if (expiryDate == null) {
      return 'Scadenza non disponibile';
    }
    if (daysToExpiry < 0) {
      return 'Scaduta da ${daysToExpiry.abs()} gg';
    }
    if (daysToExpiry == 0) {
      return 'Scade oggi';
    }
    return 'Scade tra $daysToExpiry gg';
  }
}

String _readString(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final String normalized = _readString(value).toLowerCase();
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'si' ||
      normalized == 'sì';
}

int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(_readString(value));
}

DateTime? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  final String text = _readString(value);
  if (text.isNotEmpty) {
    final DateTime? parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
  }
  try {
    final dynamic date = (value as dynamic).toDate();
    if (date is DateTime) return date;
  } catch (_) {}
  return null;
}

List<String> _readStringList(dynamic value) {
  if (value is List) {
    return value
        .map((dynamic item) => _readString(item))
        .where((String item) => item.isNotEmpty)
        .toList();
  }
  final String text = _readString(value);
  if (text.isEmpty) {
    return const <String>[];
  }
  return text
      .split(RegExp(r'[,;|\n]'))
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList();
}
