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
      drugName: (map['drugName'] ?? '') as String,
      dosage: map['dosage'] as String?,
      quantity: (map['quantity'] ?? 1) as int,
    );
  }
}
