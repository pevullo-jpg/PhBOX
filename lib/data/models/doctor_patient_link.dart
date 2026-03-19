class DoctorPatientLink {
  final String id;
  final String patientFiscalCode;
  final String doctorName;
  final DateTime? updatedAt;

  const DoctorPatientLink({
    required this.id,
    required this.patientFiscalCode,
    required this.doctorName,
    this.updatedAt,
  });

  factory DoctorPatientLink.fromMap(Map<String, dynamic> map) {
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
      doctorName: _readString(
        map['doctorName'] ??
            map['doctorFullName'] ??
            map['doctor'] ??
            map['medico'] ??
            map['doctorDisplayName'],
      ),
      updatedAt: _readDate(
        map['updatedAt'] ?? map['createdAt'] ?? map['linkedAt'],
      ),
    );
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
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
      if (seconds is int) return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    } catch (_) {}
    return null;
  }
}
