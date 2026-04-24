class Booking {
  final String id;
  final String patientFiscalCode;
  final String patientName;
  final String drugName;
  final int quantity;
  final String? note;
  final DateTime createdAt;
  final DateTime? expectedDate;
  final String status;

  const Booking({
    required this.id,
    required this.patientFiscalCode,
    required this.patientName,
    required this.drugName,
    this.quantity = 1,
    this.note,
    required this.createdAt,
    this.expectedDate,
    this.status = 'open',
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'patientFiscalCode': patientFiscalCode,
      'patientName': patientName,
      'drugName': drugName,
      'quantity': quantity,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'expectedDate': expectedDate?.toIso8601String(),
      'status': status,
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: (map['id'] ?? '') as String,
      patientFiscalCode: (map['patientFiscalCode'] ?? '') as String,
      patientName: (map['patientName'] ?? '') as String,
      drugName: (map['drugName'] ?? '') as String,
      quantity: (map['quantity'] ?? 1) as int,
      note: map['note'] as String?,
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      expectedDate: _readDate(map['expectedDate']),
      status: (map['status'] ?? 'open') as String,
    );
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
