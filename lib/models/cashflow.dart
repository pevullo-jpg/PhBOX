class Cashflow {
  final String id;
  double amount;
  String sourceId;
  String destinationId;
  bool isBoxFlow;

  bool isMonthly;
  int dayOfMonth;
  DateTime startDate;

  DateTime? annualDate;

  Cashflow({
    required this.id,
    required this.amount,
    required this.sourceId,
    required this.destinationId,
    required this.isBoxFlow,
    required this.isMonthly,
    required this.dayOfMonth,
    required this.startDate,
    this.annualDate,
  });

  factory Cashflow.fromJson(Map<String, dynamic> json) {
    return Cashflow(
      id: json['id'],
      amount: (json['amount'] ?? 0).toDouble(),
      sourceId: json['sourceId'] ?? '',
      destinationId: json['destinationId'] ?? '',
      isBoxFlow: json['isBoxFlow'] ?? true,
      isMonthly: json['isMonthly'] ?? true,
      dayOfMonth: json['dayOfMonth'] ?? 1,
      startDate: DateTime.parse(
        json['startDate'] ?? DateTime.now().toIso8601String(),
      ),
      annualDate: json['annualDate'] != null
          ? DateTime.parse(json['annualDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "amount": amount,
      "sourceId": sourceId,
      "destinationId": destinationId,
      "isBoxFlow": isBoxFlow,
      "isMonthly": isMonthly,
      "dayOfMonth": dayOfMonth,
      "startDate": startDate.toIso8601String(),
      "annualDate": annualDate?.toIso8601String(),
    };
  }
}
