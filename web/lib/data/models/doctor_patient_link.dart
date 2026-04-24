enum DoctorPatientLinkType {
  manual,
  primary,
  other,
}

class DoctorPatientLink {
  final String id;
  final String patientFiscalCode;
  final String doctorName;
  final String doctorFullName;
  final String doctorSurname;
  final DateTime? updatedAt;

  const DoctorPatientLink({
    required this.id,
    required this.patientFiscalCode,
    required this.doctorName,
    required this.doctorFullName,
    required this.doctorSurname,
    this.updatedAt,
  });

  DoctorPatientLinkType get linkType {
    final String normalizedId = id.trim().toLowerCase();
    if (normalizedId.endsWith('__manual')) {
      return DoctorPatientLinkType.manual;
    }
    if (normalizedId.endsWith('__primary')) {
      return DoctorPatientLinkType.primary;
    }
    return DoctorPatientLinkType.other;
  }

  bool get isManual => linkType == DoctorPatientLinkType.manual;
  bool get isPrimary => linkType == DoctorPatientLinkType.primary;
  bool get isStableAssociation => isManual || isPrimary;

  factory DoctorPatientLink.fromMap(Map<String, dynamic> map) {
    final String fullName = _readString(
      map['doctorFullName'] ??
          map['doctorDisplayName'] ??
          map['doctor'] ??
          map['medico'] ??
          map['doctorName'],
    );
    final String rawDoctorName = _readString(map['doctorName']);
    final String doctorSurname = _readString(map['doctorSurname']).isNotEmpty
        ? _readString(map['doctorSurname'])
        : _extractSurname(fullName.isNotEmpty ? fullName : rawDoctorName);
    final String doctorName = rawDoctorName.isNotEmpty
        ? rawDoctorName
        : (fullName.isNotEmpty ? fullName : doctorSurname);
    return DoctorPatientLink(
      id: (map['id'] ?? map['linkId'] ?? '') as String,
      patientFiscalCode: _readString(
        map['patientFiscalCode'] ??
            map['fiscalCode'] ??
            map['patientCf'] ??
            map['cf'] ??
            map['assistitoFiscalCode'] ??
            map['assistitoCf'],
      ).toUpperCase(),
      doctorName: doctorName,
      doctorFullName: fullName.isNotEmpty ? fullName : doctorName,
      doctorSurname: doctorSurname,
      updatedAt: _readDate(
        map['updatedAt'] ?? map['createdAt'] ?? map['linkedAt'],
      ),
    );
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String _extractSurname(String fullName) {
    final String normalized = fullName.trim();
    if (normalized.isEmpty) return '';
    final List<String> parts = normalized
        .split(RegExp(r'\s+'))
        .where((String e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    return parts.first.trim();
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
