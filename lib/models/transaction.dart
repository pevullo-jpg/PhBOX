class TransactionModel {
  final String id;
  String? boxId;
  String? fundId;
  double amount;
  String category;
  String note;
  DateTime date;
  bool confirmed;
  String? recurringId;

  TransactionModel({
    required this.id,
    this.boxId,
    this.fundId,
    required this.amount,
    required this.category,
    required this.note,
    required this.date,
    this.confirmed = true,
    this.recurringId,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      boxId: json['boxId'],
      fundId: json['fundId'],
      amount: (json['amount'] ?? 0).toDouble(),
      category: json['category'] ?? '',
      note: json['note'] ?? '',
      date: DateTime.parse(json['date']),
      confirmed: json['confirmed'] ?? true,
      recurringId: json['recurringId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "boxId": boxId,
      "fundId": fundId,
      "amount": amount,
      "category": category,
      "note": note,
      "date": date.toIso8601String(),
      "confirmed": confirmed,
      "recurringId": recurringId,
    };
  }
}
