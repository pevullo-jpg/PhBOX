class Debt {
  final String id;
  final String patientFiscalCode;
  final String patientName;
  final String description;
  final double amount;
  final double paidAmount;
  final double residualAmount;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String status;
  final String? note;

  const Debt({
    required this.id,
    required this.patientFiscalCode,
    required this.patientName,
    required this.description,
    required this.amount,
    required this.paidAmount,
    required this.residualAmount,
    required this.createdAt,
    this.dueDate,
    this.status = 'open',
    this.note,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'patientFiscalCode': patientFiscalCode,
      'patientName': patientName,
      'description': description,
      'amount': amount,
      'paidAmount': paidAmount,
      'residualAmount': residualAmount,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'status': status,
      'note': note,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: (map['id'] ?? '') as String,
      patientFiscalCode: (map['patientFiscalCode'] ?? '') as String,
      patientName: (map['patientName'] ?? '') as String,
      description: (map['description'] ?? '') as String,
      amount: _readDouble(map['amount']),
      paidAmount: _readDouble(map['paidAmount']),
      residualAmount: _readDouble(map['residualAmount']),
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
      dueDate: _readDate(map['dueDate']),
      status: (map['status'] ?? 'open') as String,
      note: map['note'] as String?,
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

  static double _readDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0;
  }
}
