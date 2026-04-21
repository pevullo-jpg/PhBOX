class Recurring {
  final String id;
  String title;
  double amount;
  String? boxId;
  String? fundId;
  String category;

  bool isIncome;
  bool isMonthly;
  DateTime startDate;
  int dayOfMonth;
  DateTime? annualDate;

  bool manual;
  String? groupId;

  int? durationMonths;

  Recurring({
    required this.id,
    required this.title,
    required this.amount,
    this.boxId,
    this.fundId,
    required this.category,
    this.isIncome = false,
    required this.isMonthly,
    required this.startDate,
    required this.dayOfMonth,
    this.annualDate,
    this.manual = false,
    this.groupId,
    this.durationMonths,
  });

  factory Recurring.fromJson(Map<String, dynamic> json) {
    return Recurring(
      id: json['id'],
      title: json['title'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      boxId: json['boxId'],
      fundId: json['fundId'],
      category: json['category'] ?? '',
      isIncome: json['isIncome'] ?? false,
      isMonthly: json['isMonthly'] ?? true,
      startDate: DateTime.parse(
        json['startDate'] ?? DateTime.now().toIso8601String(),
      ),
      dayOfMonth: json['dayOfMonth'] ?? 1,
      annualDate: json['annualDate'] != null
          ? DateTime.parse(json['annualDate'])
          : null,
      manual: json['manual'] ?? false,
      groupId: json['groupId'],
      durationMonths: json['durationMonths'] == null
          ? null
          : int.tryParse(json['durationMonths'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "title": title,
      "amount": amount,
      "boxId": boxId,
      "fundId": fundId,
      "category": category,
      "isIncome": isIncome,
      "isMonthly": isMonthly,
      "startDate": startDate.toIso8601String(),
      "dayOfMonth": dayOfMonth,
      "annualDate": annualDate?.toIso8601String(),
      "manual": manual,
      "groupId": groupId,
      "durationMonths": durationMonths,
    };
  }
}
