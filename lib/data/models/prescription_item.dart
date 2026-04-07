class PrescriptionItem {
  final String drugName;
  final String? dosage;
  final int quantity;

  const PrescriptionItem({
    required this.drugName,
    this.dosage,
    this.quantity = 1,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'drugName': drugName,
      'dosage': dosage,
      'quantity': quantity,
    };
  }

  factory PrescriptionItem.fromMap(Map<String, dynamic> map) {
    return PrescriptionItem(
      drugName: _readString(
        map['drugName'] ??
            map['name'] ??
            map['drug'] ??
            map['description'] ??
            map['therapy'] ??
            map['farmaco'],
      ),
      dosage: _readNullableString(map['dosage'] ?? map['dose']),
      quantity: _readInt(map['quantity'] ?? map['qty']) ?? 1,
    );
  }

  static String _readString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String? _readNullableString(dynamic value) {
    final String normalized = _readString(value);
    return normalized.isEmpty ? null : normalized;
  }

  static int? _readInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
